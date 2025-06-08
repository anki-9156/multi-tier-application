# AWS Cleanup Guide

This guide explains how to use the automated cleanup workflow to delete all AWS resources and stop charges.

## 🚨 **IMPORTANT WARNING**

**This cleanup process will permanently delete ALL your deployed resources:**
- ✅ ECS Services and Cluster
- ✅ RDS Database (including all data)
- ✅ Load Balancer and Target Groups
- ✅ VPC and all networking components
- ✅ Security Groups
- ✅ IAM Roles
- ✅ CloudWatch Log Groups
- ✅ ECR Repositories (optional)

**⚠️ This action cannot be undone. Make sure you have backups of any important data.**

## 💰 **Cost Savings**

After cleanup, you will stop paying for:
- **ECS Fargate compute** (~$30-60/month for 2 tasks)
- **RDS database** (~$15-25/month for db.t3.micro)
- **Application Load Balancer** (~$16/month)
- **NAT Gateway** (~$45/month + data processing)
- **Total estimated savings: ~$100-150/month**

## 🔧 **How to Run Cleanup**

### **Method 1: GitHub Actions UI (Recommended)**

1. **Go to your repository on GitHub**
2. **Click on "Actions" tab**
3. **Find "Cleanup AWS Resources" workflow**
4. **Click "Run workflow"**
5. **Fill in the required inputs:**
   - **Confirm deletion:** Type `DELETE` (must be exact)
   - **Keep ECR images:** `true` (recommended) or `false`
6. **Click "Run workflow" button**

### **Method 2: GitHub CLI**

```bash
# Install GitHub CLI if you haven't already
# Then run:
gh workflow run cleanup-aws.yml \
  -f confirm_deletion=DELETE \
  -f keep_ecr_images=true
```

## 📋 **Cleanup Process**

The workflow runs in this order:

### **1. Validation** (1 minute)
- Confirms you typed "DELETE" correctly
- Prevents accidental runs

### **2. ECS Cleanup** (5-10 minutes)
- Stops all running tasks
- Deletes services
- Deletes task definitions
- Removes ECS cluster
- Deletes CloudWatch log groups

### **3. Database Cleanup** (10-15 minutes)
- Deletes RDS instance
- Removes DB subnet groups
- **Note:** This is the longest step

### **4. Infrastructure Cleanup** (5-10 minutes)
- Deletes Load Balancer
- Removes Target Groups
- Deletes NAT Gateway
- Releases Elastic IPs
- Removes Internet Gateway
- Deletes Security Groups
- Removes Subnets and VPC
- Deletes IAM Roles

### **5. ECR Cleanup** (2-5 minutes, optional)
- Only runs if you set `keep_ecr_images=false`
- Deletes all Docker images
- Removes ECR repositories

## ⏱️ **Total Time**

**Estimated completion time: 20-40 minutes**

The process runs automatically - you don't need to babysit it.

## 📊 **Monitoring Progress**

1. **GitHub Actions page** shows real-time progress
2. **Each step** shows detailed logs
3. **Summary page** shows final status
4. **AWS Console** can be used to verify deletion

## 🔄 **Re-deploying After Cleanup**

To deploy again after cleanup:

1. **Push to main branch** (triggers deployment workflow)
2. **Or run "Deploy to AWS" workflow manually**
3. **All resources will be recreated fresh**

## 🛡️ **Safety Features**

- **Manual trigger only** - Never runs automatically
- **Confirmation required** - Must type "DELETE"
- **Sequential execution** - Steps run in safe order
- **Error handling** - Won't crash if resources don't exist
- **Detailed logging** - Shows what's happening

## ❓ **Troubleshooting**

### **"Validation failed"**
- Make sure you typed exactly `DELETE` (case-sensitive)

### **"Resource not found" errors**
- Normal - means resource was already deleted
- Script continues safely

### **RDS deletion timeout**
- Normal - RDS can take 15+ minutes
- Check AWS Console for progress

### **VPC deletion failed**
- Usually means there are still dependencies
- Check for remaining ENIs or Lambda functions
- May need manual cleanup in AWS Console

## 💡 **Best Practices**

### **Before Cleanup:**
- ✅ Export any important data from RDS
- ✅ Download any logs you need
- ✅ Document any custom configurations

### **ECR Images:**
- ✅ **Keep images** (default) - allows faster re-deployment
- ✅ **Delete images** only if you want complete cleanup

### **Scheduling:**
- ✅ Run cleanup at **end of day/week** to save costs
- ✅ Re-deploy in the **morning** when you need to work

## 📞 **Support**

If you encounter issues:

1. **Check the workflow logs** in GitHub Actions
2. **Verify in AWS Console** what resources remain
3. **Re-run the workflow** - it's safe to run multiple times
4. **Manual cleanup** in AWS Console if needed

## 🔄 **Workflow Commands**

```yaml
# Cleanup with keeping ECR images
confirm_deletion: "DELETE"
keep_ecr_images: true

# Complete cleanup (including ECR)
confirm_deletion: "DELETE"
keep_ecr_images: false
```

Remember: This workflow is designed to save you money by cleaning up resources when not in use! 💰 