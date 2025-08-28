import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { handle } from 'hono/cloudflare-pages'
import { createClient } from '@supabase/supabase-js'

type Bindings = {
  SUPABASE_URL: string
  SUPABASE_ANON_KEY: string
  SUPABASE_SERVICE_ROLE: string
}

const app = new Hono<{ Bindings: Bindings }>()

// Enable CORS for frontend-backend communication
app.use('*', cors())

app.get('/api/health', (c) => {
  return c.json({ message: 'WOW Scales API is healthy', timestamp: new Date().toISOString() })
})

// GET: list verifications (read-only → anon key)
app.get('/api/verifications', async (c) => {
  try {
    const { SUPABASE_URL, SUPABASE_ANON_KEY } = c.env
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false } })

    const { data, error } = await supabase
      .from('verifications')
      .select('*')
      .order('created_at', { ascending: false })

    if (error) throw error

    // Optionally enrich with client fields (simple second query per client_id)
    const clientIds = Array.from(new Set((data || []).map((v) => v.client_id).filter(Boolean)))
    let clientsMap = new Map<number, any>()
    if (clientIds.length) {
      const { data: clients, error: cErr } = await supabase
        .from('clients')
        .select('id, client_name, address')
        .in('id', clientIds as number[])
      if (cErr) throw cErr
      for (const cl of clients || []) clientsMap.set(cl.id, cl)
    }

    const verifications = (data || []).map((v) => ({
      ...v,
      client_name: clientsMap.get(v.client_id)?.client_name ?? null,
      address: clientsMap.get(v.client_id)?.address ?? null,
    }))

    return c.json({ verifications })
  } catch (error) {
    return c.json({ error: 'Failed to fetch verifications' }, 500)
  }
})

// POST: create verification (write → service role)
app.post('/api/verifications', async (c) => {
  try {
    const { SUPABASE_URL, SUPABASE_SERVICE_ROLE } = c.env
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, { auth: { persistSession: false } })
    const data = await c.req.json()

    // 1) Insert client
    const { data: clientData, error: clientErr } = await supabase
      .from('clients')
      .insert({
        client_name: data.client.clientName,
        address: data.client.address,
        phone: data.client.phone || null,
        email: data.client.email || null,
      })
      .select('id')
      .single()
    if (clientErr) throw clientErr
    const clientId = clientData.id

    // 2) Insert verification
    const { data: verData, error: verErr } = await supabase
      .from('verifications')
      .insert({
        certificate_no: data.header.certNo,
        verification_date: data.header.date,
        verification_sticker: data.header.verSticker,
        client_id: clientId,
        status_type: data.status.status,
        accuracy_type: data.status.accType,
      })
      .select('id')
      .single()
    if (verErr) throw verErr
    const verificationId = verData.id

    // 3) Insert instrument
    const { error: instrErr } = await supabase
      .from('instruments')
      .insert({
        verification_id: verificationId,
        manufacturer: data.instrument.manufacturer,
        model: data.instrument.model,
        serial_number: data.instrument.serial,
        accuracy_class: data.instrument.class,
        units: data.instrument.units,
        max_capacity: data.instrument.max,
        max_test_load_available: data.instrument.maxAvail,
        verification_interval_e: data.instrument.e,
        min_capacity: data.instrument.min,
        sa_number: data.instrument.saNr,
        aa_number: data.instrument.aaNr,
        software_version: data.instrument.software,
        sealing_method: data.instrument.sealing,
        equipment_notes: data.instrument.equipNotes,
      })
    if (instrErr) throw instrErr

    // 4) Insert accuracy tests (bulk)
    if (Array.isArray(data.accuracy) && data.accuracy.length) {
      const payload = data.accuracy.map((acc: any) => ({
        verification_id: verificationId,
        test_load: acc.load ?? null,
        make_up: acc.makeUp ?? null,
        indication: acc.indication ?? null,
        run_up_load: acc.runUpLoad ?? null,
        run_down_load: acc.runDownLoad ?? null,
        switch_point_load: acc.switchPointLoad ?? null,
        error_value: acc.errorValue ?? null,
        band: acc.band ?? null,
        mpe_value: acc.mpeValue ?? null,
        result: acc.result ?? null,
      }))
      const { error } = await supabase.from('accuracy_tests').insert(payload)
      if (error) throw error
    }

    // 5) Variation test
    if (data.variation) {
      const { error } = await supabase.from('variation_tests').insert({
        verification_id: verificationId,
        applied_load: data.variation.appliedLoad ?? null,
        reference_indication: data.variation.referenceIndication ?? null,
        end1_indication: data.variation.end1 ?? null,
        middle_indication: data.variation.middle ?? null,
        end2_indication: data.variation.end2 ?? null,
      })
      if (error) throw error
    }

    // 6) Repeatability test
    if (data.repeatability) {
      const { error } = await supabase.from('repeatability_tests').insert({
        verification_id: verificationId,
        target_test_load: data.repeatability.targetLoad ?? null,
        run1_indication: data.repeatability.run1 ?? null,
        run2_indication: data.repeatability.run2 ?? null,
        run3_indication: data.repeatability.run3 ?? null,
      })
      if (error) throw error
    }

    // 7) Officer
    const { error: officerErr } = await supabase.from('verification_officers').insert({
      verification_id: verificationId,
      officer_name: data.officer.officerName ?? null,
      officer_id: data.officer.officerId ?? null,
      sanas_lab_no: data.officer.sanasLabNo ?? null,
      seal_id: data.officer.sealId ?? null,
      signature: data.officer.signature ?? null,
    })
    if (officerErr) throw officerErr

    return c.json({ success: true, verificationId, message: 'Verification saved successfully' })
  } catch (error) {
    console.error('Error saving verification:', error)
    return c.json({ error: 'Failed to save verification' }, 500)
  }
})

// GET: single verification and related data (read-only → anon key)
app.get('/api/verifications/:id', async (c) => {
  try {
    const { SUPABASE_URL, SUPABASE_ANON_KEY } = c.env
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false } })
    const id = Number(c.req.param('id'))

    const { data: verification, error: verErr } = await supabase
      .from('verifications')
      .select('*')
      .eq('id', id)
      .single()
    if (verErr) throw verErr

    const clientId = verification?.client_id
    let client: any = null
    if (clientId) {
      const { data: cData, error: cErr } = await supabase
        .from('clients')
        .select('client_name,address,phone,email')
        .eq('id', clientId)
        .single()
      if (cErr) throw cErr
      client = cData
    }

    const { data: accuracyTests, error: accErr } = await supabase
      .from('accuracy_tests')
      .select('*')
      .eq('verification_id', id)
      .order('id', { ascending: true })
    if (accErr) throw accErr

    const { data: variationTest, error: varErr } = await supabase
      .from('variation_tests')
      .select('*')
      .eq('verification_id', id)
      .maybeSingle()
    if (varErr) throw varErr

    const { data: repeatabilityTest, error: repErr } = await supabase
      .from('repeatability_tests')
      .select('*')
      .eq('verification_id', id)
      .maybeSingle()
    if (repErr) throw repErr

    return c.json({
      verification: {
        ...verification,
        client_name: client?.client_name ?? null,
        address: client?.address ?? null,
        phone: client?.phone ?? null,
        email: client?.email ?? null,
      },
      accuracyTests: accuracyTests || [],
      variationTest: variationTest || null,
      repeatabilityTest: repeatabilityTest || null,
    })
  } catch (error) {
    return c.json({ error: 'Failed to fetch verification' }, 500)
  }
})

export default app

// Cloudflare Pages Functions adapter
export const onRequest = handle(app)
