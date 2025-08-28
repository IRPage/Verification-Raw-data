import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { handle } from 'hono/cloudflare-pages'

type Bindings = {
  DB: D1Database;
}

const app = new Hono<{ Bindings: Bindings }>()

// Enable CORS for frontend-backend communication
app.use('*', cors())

// API routes
app.get('/api/health', (c) => {
  return c.json({ message: 'WOW Scales API is healthy', timestamp: new Date().toISOString() })
})

// Verification records endpoints (D1)
app.get('/api/verifications', async (c) => {
  try {
    const { DB } = c.env;
    const { results } = await DB.prepare(`
      SELECT v.*, c.client_name, c.address 
      FROM verifications v
      LEFT JOIN clients c ON v.client_id = c.id
      ORDER BY v.created_at DESC
    `).all();
    
    return c.json({ verifications: results });
  } catch (error) {
    return c.json({ error: 'Failed to fetch verifications' }, 500);
  }
});

app.post('/api/verifications', async (c) => {
  try {
    const { DB } = c.env;
    const data = await c.req.json();
    
    // Insert client first
    const clientResult = await DB.prepare(`
      INSERT INTO clients (client_name, address, phone, email)
      VALUES (?, ?, ?, ?)
      RETURNING id
    `).bind(
      data.client.clientName,
      data.client.address,
      data.client.phone || null,
      data.client.email || null
    ).first();
    
    const clientId = clientResult?.id;
    
    // Insert verification
    const verificationResult = await DB.prepare(`
      INSERT INTO verifications (
        certificate_no, verification_date, verification_sticker,
        client_id, status_type, accuracy_type,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
      RETURNING id
    `).bind(
      data.header.certNo,
      data.header.date,
      data.header.verSticker,
      clientId,
      data.status.status,
      data.status.accType
    ).first();
    
    const verificationId = verificationResult?.id;
    
    // Insert instrument
    await DB.prepare(`
      INSERT INTO instruments (
        verification_id, manufacturer, model, serial_number,
        accuracy_class, units, max_capacity, max_test_load_available,
        verification_interval_e, min_capacity,
        sa_number, aa_number, software_version, sealing_method,
        equipment_notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
    `).bind(
      verificationId,
      data.instrument.manufacturer,
      data.instrument.model,
      data.instrument.serial,
      data.instrument.class,
      data.instrument.units,
      data.instrument.max,
      data.instrument.maxAvail,
      data.instrument.e,
      data.instrument.min,
      data.instrument.saNr,
      data.instrument.aaNr,
      data.instrument.software,
      data.instrument.sealing,
      data.instrument.equipNotes
    ).run();
    
    // Insert accuracy test results
    if (data.accuracy && data.accuracy.length > 0) {
      for (const acc of data.accuracy) {
        await DB.prepare(`
          INSERT INTO accuracy_tests (
            verification_id, test_load, make_up, indication,
            run_up_load, run_down_load, switch_point_load,
            error_value, band, mpe_value, result, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        `).bind(
          verificationId,
          acc.load || null,
          acc.makeUp || null,
          acc.indication || null,
          acc.runUpLoad || null,
          acc.runDownLoad || null,
          acc.switchPointLoad || null,
          acc.errorValue || null,
          acc.band || null,
          acc.mpeValue || null,
          acc.result || null
        ).run();
      }
    }
    
    // Insert variation test
    if (data.variation) {
      await DB.prepare(`
        INSERT INTO variation_tests (
          verification_id, applied_load, reference_indication,
          end1_indication, middle_indication, end2_indication,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
      `).bind(
        verificationId,
        data.variation.appliedLoad || null,
        data.variation.referenceIndication || null,
        data.variation.end1 || null,
        data.variation.middle || null,
        data.variation.end2 || null
      ).run();
    }
    
    // Insert repeatability test
    if (data.repeatability) {
      await DB.prepare(`
        INSERT INTO repeatability_tests (
          verification_id, target_test_load,
          run1_indication, run2_indication, run3_indication,
          created_at
        ) VALUES (?, ?, ?, ?, ?, datetime('now'))
      `).bind(
        verificationId,
        data.repeatability.targetLoad || null,
        data.repeatability.run1 || null,
        data.repeatability.run2 || null,
        data.repeatability.run3 || null
      ).run();
    }
    
    // Insert verification officer info
    await DB.prepare(`
      INSERT INTO verification_officers (
        verification_id, officer_name, officer_id,
        sanas_lab_no, seal_id, signature, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
    `).bind(
      verificationId,
      data.officer.officerName || null,
      data.officer.officerId || null,
      data.officer.sanasLabNo || null,
      data.officer.sealId || null,
      data.officer.signature || null
    ).run();
    
    return c.json({ 
      success: true, 
      verificationId,
      message: 'Verification saved successfully' 
    });
    
  } catch (error) {
    console.error('Error saving verification:', error);
    return c.json({ error: 'Failed to save verification' }, 500);
  }
});

app.get('/api/verifications/:id', async (c) => {
  try {
    const { DB } = c.env;
    const id = c.req.param('id');
    
    // Get verification with related data
    const verification = await DB.prepare(`
      SELECT v.*, c.client_name, c.address, c.phone, c.email,
             i.*, vo.officer_name, vo.officer_id, vo.sanas_lab_no, vo.seal_id, vo.signature
      FROM verifications v
      LEFT JOIN clients c ON v.client_id = c.id
      LEFT JOIN instruments i ON v.id = i.verification_id
      LEFT JOIN verification_officers vo ON v.id = vo.verification_id
      WHERE v.id = ?
    `).bind(id).first();
    
    if (!verification) {
      return c.json({ error: 'Verification not found' }, 404);
    }
    
    // Get accuracy tests
    const accuracyTests = await DB.prepare(`
      SELECT * FROM accuracy_tests WHERE verification_id = ? ORDER BY id
    `).bind(id).all();
    
    // Get variation test
    const variationTest = await DB.prepare(`
      SELECT * FROM variation_tests WHERE verification_id = ?
    `).bind(id).first();
    
    // Get repeatability test
    const repeatabilityTest = await DB.prepare(`
      SELECT * FROM repeatability_tests WHERE verification_id = ?
    `).bind(id).first();
    
    return c.json({ 
      verification,
      accuracyTests: accuracyTests.results || [],
      variationTest,
      repeatabilityTest
    });
    
  } catch (error) {
    return c.json({ error: 'Failed to fetch verification' }, 500);
  }
});

export default app

// Cloudflare Pages Functions adapter
export const onRequest = handle(app)
