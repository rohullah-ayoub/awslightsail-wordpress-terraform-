"use strict";

console.log("Loading function");

var AWS = require("aws-sdk");

var lightsail = new AWS.Lightsail();
const AUTO_SNAPSHOT_SUFFIX = "auto";

exports.handler = (event, context, callback) => {
  // Create new snapshot
  createSnapshot(process.env.INSTANCE_NAME, function (err, snapshotName) {
    if (err) {
      context.fail(err);
    } else {
      console.log(`Created Snapshot with name: ${snapshotName}`);

      context.succeed(`Created Snapshot with name: ${snapshotName}`)
    }
  })

};

/**
 * @description Creates a new instance snapshot of the Lightsail instance
 * @param instanceName: The name of the Lighstail instance to create a snapshot from.
 */
function createSnapshot(instanceName, callback) {
  const snapshotName = `${instanceName}-system-${Date.now() *
    1000}-${AUTO_SNAPSHOT_SUFFIX}`;
  const options = {
    instanceName: instanceName,
    instanceSnapshotName: snapshotName
  };

  lightsail.createInstanceSnapshot(options, function (err, data) {
    if (err) {
      callback(err);
    } else {
      callback(null, snapshotName);
    }
  });
}