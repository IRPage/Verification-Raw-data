// Simple development server for the Hono backend
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { serve } from '@hono/node-server';

const app = new Hono();

// Enable CORS for frontend-backend communication
app.use('*', cors());

// Mock database for development
const mockDB = {
  verifications: [],
  clients: [],
  
  // Mock health check
  health: () => ({ message: 'WOW Scales API is healthy', timestamp: new Date().toISOString() }),
  
  // Mock verifications
  getVerifications: () => mockDB.verifications,
  saveVerification: (data) => {
    const id = mockDB.verifications.length + 1;
    mockDB.verifications.push({ id, ...data, created_at: new Date().toISOString() });
    return { success: true, verificationId: id, message: 'Verification saved successfully' };
  }
};

// API routes
app.get('/api/health', (c) => {
  return c.json(mockDB.health());
});

app.get('/api/verifications', (c) => {
  return c.json({ verifications: mockDB.getVerifications() });
});

app.post('/api/verifications', async (c) => {
  try {
    const data = await c.req.json();
    const result = mockDB.saveVerification(data);
    return c.json(result);
  } catch (error) {
    return c.json({ error: 'Failed to save verification' }, 500);
  }
});

app.get('/api/verifications/:id', (c) => {
  const id = parseInt(c.req.param('id'));
  const verification = mockDB.verifications.find(v => v.id === id);
  
  if (!verification) {
    return c.json({ error: 'Verification not found' }, 404);
  }
  
  return c.json({ verification });
});

// Start server
const port = process.env.PORT || 3000;
console.log(`🚀 Server running on http://localhost:${port}`);

serve({
  fetch: app.fetch,
  port: port
});
