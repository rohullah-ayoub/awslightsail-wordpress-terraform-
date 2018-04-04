'use strict';

console.log('Loading function');

var AWS = require('aws-sdk');

var lightsail = new AWS.Lightsail();
const AUTO_SNAPSHOT_SUFFIX = 'auto'



exports.handler = (event, context, callback) => {

  // Create new snapshot
  createSnapshot(process.env.INSTANCE_NAME)

  // Prune existing snapshots
  let retentionPeriod = new Date()
  retentionPeriod.setDate(retentionPeriod.getDate() - process.env.RETENTION_PERIOD)
  pruneSnapshots(retentionPeriod)

};

/**
 * @description Creates a new instance snapshot of the Lightsail instance
 * @param instanceName: The name of the Lighstail instance to create a snapshot from.
 */
function createSnapshot(instanceName) {

  const snapshotName = `${instanceName}-system-${Date.now() * 1000}-${AUTO_SNAPSHOT_SUFFIX}`
  const options = {
    instanceName: 'Wordpress',
    instanceSnapshotName: snapshotName
  }

  lightsail.createInstanceSnapshot(options, function (err, data) {

    if (err) {
      context.fail(err)
    }

    console.log(`Created Snapshot with name: ${snapshotName}`)
  })
}

/**
 * @description Prunes the existing snapshots of the Lightsail instance by removing the snapshots that were created before the retentionPeriod.
 * @param retentionPeriod: The date to determine whether to retain the snapshot. If snapshot was created before this date, it will be deleted.
 */
function pruneSnapshots(retentionPeriod) {

  lightsail.getInstanceSnapshots({}, function (err, data) {
    if (err) {
      context.fail(err)
    }

    data.instanceSnapshots.forEach(function (snapshot) {
      const hasElapsedRetentionPeriod = (Date.now() - snapshot.createdAt) > retentionPeriod
      const istAutomatedSnapshot = snapshot.name.endsWith(AUTO_SNAPSHOT_SUFFIX)

      if (istAutomatedSnapshot && hasElapsedRetentionPeriod) {
        lightsail.deleteInstanceSnapshot({
          instanceSnapshotName: snapshot.name
        }, function (err, res) {
          if (err) {
            context.fail(err)
          }

          console.log(`Deleted Snapshot with name: ${snapshot.name}`)
        })
      }
    })
  })
}