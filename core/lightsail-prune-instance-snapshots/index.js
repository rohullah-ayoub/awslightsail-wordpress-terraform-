"use strict";

console.log("Loading function");

var AWS = require("aws-sdk");


var lightsail = new AWS.Lightsail();
const AUTO_SNAPSHOT_SUFFIX = "auto";

exports.handler = (event, context, callback) => {
  // Prune existing snapshots
  let retentionPeriod = new Date();
  retentionPeriod.setDate(
    retentionPeriod.getDate() - process.env.RETENTION_PERIOD
  );
  pruneSnapshots(retentionPeriod, function (err, snapshotName) {
    if (err) {
      context.fail(err);
    } else {
      context.succeed('Snapshots pruning completed')
    }
  });
};

/**
 * @description Prunes the existing snapshots of the Lightsail instance by removing the snapshots that were created before the retentionPeriod.
 * @param retentionPeriod: The date to determine whether to retain the snapshot. If snapshot was created before this date, it will be deleted.
 */
function pruneSnapshots(retentionPeriod, callback) {
  lightsail.getInstanceSnapshots({}, function (err, data) {
    if (err) {
      callback(err);
    }

    let promises = [];

    data.instanceSnapshots.forEach(function (snapshot) {
      const hasElapsedRetentionPeriod = new Date(snapshot.createdAt).getTime() < retentionPeriod.getTime();

      const istAutomatedSnapshot = snapshot.name.endsWith(AUTO_SNAPSHOT_SUFFIX);


      if (istAutomatedSnapshot && hasElapsedRetentionPeriod) {
        const deleteInstanceSnapshot = lightsail.deleteInstanceSnapshot({
          instanceSnapshotName: snapshot.name
        }).promise();
        promises.push(deleteInstanceSnapshot.then(function (res) {
          return snapshot.name;
        }))

      }

    });

    Promise.all(promises).then(function (values) {

      console.log("Snapshots removed:");
      values.forEach(function (value) {
        console.log(value);
      })

      callback(null, values);
    }).catch(callback);
  });
}