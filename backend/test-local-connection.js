#!/usr/bin/env node

// Load environment variables from .env file
require('dotenv').config();

const { Sequelize } = require('sequelize');

async function testDatabaseConnection() {
  console.log('🔍 Testing PostgreSQL database connection...\n');
  
  // Display environment variables (mask password)
  console.log('📊 Environment Variables:');
  console.log('   DB_HOST:', process.env.DB_HOST || '❌ NOT SET');
  console.log('   DB_PORT:', process.env.DB_PORT || '❌ NOT SET'); 
  console.log('   DB_NAME:', process.env.DB_NAME || '❌ NOT SET');
  console.log('   DB_USER:', process.env.DB_USER || '❌ NOT SET');
  console.log('   DB_PASSWORD:', process.env.DB_PASSWORD ? '✅ SET' : '❌ NOT SET');
  console.log('   NODE_ENV:', process.env.NODE_ENV || 'development');
  console.log('');

  // Validate required environment variables
  const requiredVars = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];
  const missingVars = requiredVars.filter(varName => !process.env[varName]);
  
  if (missingVars.length > 0) {
    console.error('❌ Missing required environment variables:', missingVars.join(', '));
    console.error('💡 Please copy env.template to .env and fill in your RDS details');
    process.exit(1);
  }

  // Create Sequelize instance
  const sequelize = new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASSWORD,
    {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT || 5432,
      dialect: 'postgres',
      logging: false, // Set to console.log to see SQL queries
      dialectOptions: {
        ssl: process.env.NODE_ENV === 'production' ? {
          require: true,
          rejectUnauthorized: false
        } : false,
        connectTimeout: 60000,
      },
      pool: {
        max: 5,
        min: 0,
        acquire: 30000,
        idle: 10000
      }
    }
  );

  try {
    console.log('🔌 Attempting to connect to PostgreSQL...');
    
    // Test the connection
    await sequelize.authenticate();
    console.log('✅ Database connection successful!\n');
    
    // Test a simple query
    console.log('📝 Testing database query...');
    const [results] = await sequelize.query('SELECT version() as db_version, current_database() as db_name, current_user as db_user');
    
    console.log('📋 Database Information:');
    console.log('   Version:', results[0].db_version);
    console.log('   Database:', results[0].db_name);
    console.log('   User:', results[0].db_user);
    console.log('');
    
    // Test connection pool
    console.log('🏊 Testing connection pool...');
    const activeConnections = sequelize.connectionManager.pool.size;
    console.log('   Active connections:', activeConnections);
    
    console.log('🎉 All tests passed! Your database connection is working correctly.');
    
  } catch (error) {
    console.error('❌ Database connection failed!\n');
    
    // Provide specific error guidance
    if (error.code === 'ENOTFOUND') {
      console.error('🔍 DNS Resolution Error:');
      console.error('   The database host could not be found.');
      console.error('   Please check your DB_HOST value in .env file.');
    } else if (error.code === 'ECONNREFUSED') {
      console.error('🚫 Connection Refused:');
      console.error('   The database server refused the connection.');
      console.error('   Check if the database is running and accessible.');
    } else if (error.code === 'ETIMEDOUT') {
      console.error('⏰ Connection Timeout:');
      console.error('   The connection attempt timed out.');
      console.error('   Check security groups and network connectivity.');
    } else if (error.message.includes('authentication failed')) {
      console.error('🔐 Authentication Error:');
      console.error('   Username or password is incorrect.');
      console.error('   Check your DB_USER and DB_PASSWORD values.');
    } else if (error.message.includes('no pg_hba.conf entry')) {
      console.error('🛡️  Host-Based Authentication Error:');
      console.error('   The database is rejecting your connection.');
      console.error('   This is the same error you\'re seeing in ECS logs.');
      console.error('   Check your RDS security groups and parameter groups.');
    }
    
    console.error('\n📝 Full Error Details:');
    console.error('   Code:', error.code);
    console.error('   Message:', error.message);
    
    if (process.env.DEBUG) {
      console.error('\n🐛 Debug Info (full error):');
      console.error(error);
    }
    
  } finally {
    await sequelize.close();
  }
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Run the test
testDatabaseConnection(); 