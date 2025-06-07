#!/usr/bin/env node

const { Sequelize } = require('sequelize');

async function testDatabaseConnection() {
  console.log('🔍 ECS Database Connection Test');
  console.log('==============================\n');
  
  // Get environment variables from ECS task definition
  const dbConfig = {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD
  };
  
  console.log('📊 Configuration:');
  console.log('   Host:', dbConfig.host || '❌ NOT SET');
  console.log('   Port:', dbConfig.port);
  console.log('   Database:', dbConfig.database || '❌ NOT SET');
  console.log('   Username:', dbConfig.username || '❌ NOT SET');
  console.log('   Password:', dbConfig.password ? '✅ SET' : '❌ NOT SET');
  console.log('');

  if (!dbConfig.host || !dbConfig.database || !dbConfig.username || !dbConfig.password) {
    console.error('❌ Missing required environment variables');
    process.exit(1);
  }

  const sequelize = new Sequelize(
    dbConfig.database,
    dbConfig.username,
    dbConfig.password,
    {
      host: dbConfig.host,
      port: dbConfig.port,
      dialect: 'postgres',
      logging: console.log,
      dialectOptions: {
        ssl: {
          require: true,
          rejectUnauthorized: false
        },
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
    console.log('🔌 Testing connection from ECS...');
    
    await sequelize.authenticate();
    console.log('✅ Connection successful!\n');
    
    const [results] = await sequelize.query(`
      SELECT 
        version() as db_version,
        current_database() as db_name,
        current_user as db_user,
        inet_server_addr() as server_ip,
        inet_client_addr() as client_ip
    `);
    
    console.log('📋 Connection Details:');
    console.log('   Database Version:', results[0].db_version);
    console.log('   Database Name:', results[0].db_name);
    console.log('   Connected User:', results[0].db_user);
    console.log('   Server IP:', results[0].server_ip);
    console.log('   Client IP:', results[0].client_ip);
    console.log('');
    
    console.log('🎉 SUCCESS: Database connection working from ECS!');
    
  } catch (error) {
    console.error('❌ Connection failed from ECS:');
    console.error('   Error:', error.message);
    console.error('   Code:', error.code);
    
    if (error.message.includes('no pg_hba.conf entry')) {
      console.error('\n🛡️  This is the same pg_hba.conf error from your logs!');
      console.error('   The issue is with RDS authentication configuration.');
    }
    
    console.error('\nFull error for debugging:');
    console.error(error);
    
  } finally {
    await sequelize.close();
  }
}

testDatabaseConnection(); 