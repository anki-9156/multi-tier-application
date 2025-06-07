# Database Connection Testing Guide

## Quick Setup

1. **Copy the environment template:**
   ```bash
   cp env.template .env
   ```

2. **Edit the `.env` file with your RDS details:**
   ```bash
   # Get these values from AWS RDS Console
   DB_HOST=your-rds-endpoint.amazonaws.com
   DB_PORT=5432
   DB_NAME=database-2
   DB_USER=postgres
   DB_PASSWORD=your-actual-password
   NODE_ENV=development
   ```

3. **Find your RDS endpoint:**
   - Go to AWS RDS Console
   - Click on "Databases"
   - Click on "database-2"
   - Copy the endpoint from "Connectivity & security" section

4. **Install dependencies (if not already done):**
   ```bash
   npm install
   ```

5. **Run the connection test:**
   ```bash
   node test-local-connection.js
   ```

## What the test will check:

✅ Environment variables are set  
✅ Database connection works  
✅ Basic SQL query execution  
✅ Connection pool status  

## Common Error Solutions:

### `ENOTFOUND` Error
- **Issue**: DNS cannot resolve your RDS endpoint
- **Solution**: Double-check your `DB_HOST` value

### `ECONNREFUSED` Error  
- **Issue**: Database server is not accepting connections
- **Solution**: Check if RDS instance is running

### `ETIMEDOUT` Error
- **Issue**: Connection timeout (network/security issue)
- **Solution**: Verify security groups allow your IP

### `no pg_hba.conf entry` Error
- **Issue**: Same error as in your ECS logs
- **Solution**: This confirms it's a security group or RDS configuration issue

## Debug Mode

For more detailed error information:
```bash
DEBUG=true node test-local-connection.js
```

## Next Steps

Once local connection works:
1. Verify the same credentials work in your ECS task definition
2. Ensure ECS security group has outbound rules to RDS
3. Check ECS service logs for any remaining issues 