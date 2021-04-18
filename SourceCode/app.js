//Express server
const express = require('express')
const app = express()
const port = 3000

//EC2 metadata endpoint
var metadata = require('node-ec2-metadata');

// Load the SDK for JavaScript
var AWS = require('aws-sdk');

// Load credentials and set region from JSON file
AWS.config.update({region: 'ap-southeast-2'});

// Create EC2 service object
var ec2 = new AWS.EC2({apiVersion: '2016-11-15'});

//variables
var ec2TextDescription = [];
var ec2VPCTextDescription = [];

 metadata.getMetadataForInstance('instance-id')
  .then(function(instanceId) {
    if(instanceId) {
      
      var params = {
        DryRun: false,
        //InstanceIds: ['i-094b796716a0df03c']
        InstanceIds: [instanceId]
      };

      //Describe Instances
      ec2.describeInstances(params, function(err, data) {
          if (!err) {      
            ec2TextDescription = data;
          }
      });
    }
  })
  .fail(function(error) {
      console.log("Error: " + error);
  });

// Describes the specified VPC.
var params = {
    VpcIds: ["vpc-0f7a69654524594d5"]
   };

//Describe VPC's
ec2.describeVpcs(params, function(err, data) {
    if (!err) {
      ec2VPCTextDescription = data;
    }
});

app.get('/', (req, res) => {
  res.send({ec2TextDescription, ec2VPCTextDescription});
});

app.listen(port, () => {
    console.log(`AWS Describe app listening at http://localhost:${port}`)
});

