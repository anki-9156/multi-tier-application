const { Client } = require('pg');
require('dotenv').config();

const client = new Client({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

client.connect()
  .then(() => {
    console.log('✅ Connected to RDS PostgreSQL successfully!');
    return client.end();
  })
  .catch((err) => {
    console.error('❌ Failed to connect to RDS PostgreSQL:', err.message);
    if (err.message && err.message.includes('ETIMEDOUT')) {
      console.error('🔎 HINT: Connection timed out. Check that:');
      console.error('- Your RDS instance is publicly accessible or your network can reach it.');
      console.error('- The security group allows inbound connections on port 5432 from your IP.');
      console.error('- The RDS endpoint, username, and password are correct.');
    }
    process.exit(1);
  });
