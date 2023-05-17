# eznap

Extremely Simple ZFS Snapshotter

## Overview

`eznap` is a pure `bash`, `zfs-auto-snapshot`-inspired, extremely
simple, zero-configuration snapshotter suite for ZFS.

This application adheres to the KISS principle and only does one thing -
rolling ZFS snapshots.

Wherever a _dataset_ is mentioned, _volume_ is implied, too.

## Requirements

Hard:
  - bash > 4.0.0

Soft:
  - cron-like mechanism (`systemd.timer` units included)

`eznap` script can be called manually without any limitation (hence the "soft"
requirement) but the whole point of rolling snapshosts is that they are
automated.


## How does it work?

`eznap` uses _labels_ to determine the frequency of snapshots. The labels are:

  - frequent (recommended every 15 minutes)
  - hourly
  - daily
  - weekly
  - monthly

_"Zero-configuration"_ means `eznap` itself doesn't have any configuration.
Everything is driven by zfs _properties_, for example `com.sun:auto-snapshot:hourly=8`.

### Setup ZFS datasets

Each dataset with `com.sun:auto-snapshot` property set to `true` will be snapshotted
with default retention policies:

  - `com.sun:auto-snapshot=true`

Datasets without this are completely ignored by `eznap`, even for _extraneous snapshot deletion_.

All labels are enabled by default with default retention policies. To disable a specific label:

  - `com.sun.auto-snapshot:<label>=false`

To enable a label explicitly (like when the property is inherited):

  - `com.sun.auto-snapshot:<label>=true`

To enable a label with a _custom retention policy_:

  - `com.sun.auto-snapshot:<label>=<integer>`

`<label>` is a keyword described above (`frequent`, `daily`, etc.)

Setting the property to `0` is permitted and will delete all snapshots with that label.


### Retention policy

Only a limited number of snapshots is kept per each dataset and frequency
group. The number of snapshots is determined by _retention policy_.

**DEFAULT** retention policies:
  - frequent = 96
  - hourly = 48
  - daily = 14
  - weekly = 8
  - monthly = 12

These vaules are (currently) hardcoded.

**CUSTOM** retention policy means the number of snapshots in the frequency
group is set by the `com.sun:auto-snapshot:<label>` property.

Setting the property to `false` or anything else that `eznap` doesn't understand
(like random strings, negative integers, etc.) will disable snapshots for that
label (same as if `com.sun:auto-snapshot` was set to `false` or not set at all).


## Usage

First make sure to set the properties on all your datasets that you wish to
snapshot:

```
zfs set -o com.sun:auto-snapshot=true  tank
zfs set -o com.sun:auto-snapshot=false tank/nosnapshots

zfs set -o com.sun:auto-snapshot:hourly=8 tank/data
zfs set -o com.sun:auto-snapshot:hourly=false tank/data/ephemeral

...

```

Manual invocation:
```bash
$ eznap <label>
```

Cron:
```cron
*/15 * * * *  eznap frequent
@hourly       eznap hourly
@daily        eznap daily
@weekly       eznap weekly
@monthly      eznap montly
```

Systemd (with the included timers, recommended):
```
systemctl enable eznap-frequent.timer
systemctl enable eznap-hourly.timer
systemctl enable eznap-daily.timer
systemctl enable eznap-weekly.timer
systemctl enable eznap-monthly.timer
```

Whenever `eznap <label>` is executed, new snapshots will be created for the
`<label>` group and old snapshots will be destroyed in the group if any exist.

The user executing `eznap` must have the rights to create and delete snapshots,
such as by `zfs-allow(8)`, or being root.

That's it!


