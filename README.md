# eznap

Extremely Simple ZFS Snapshotter

## Overview

`eznap` is an (almost) pure `bash`, `zfs-auto-snapshot`-inspired, extremely
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

`eznap` uses "labels" to determine the frequency of snapshots. The labels are:

  - frequent (every 15 minutes)
  - hourly
  - daily
  - weekly
  - monthly

Lets call this mechanics a _frequency group_.

_"Zero-configuration"_ means `eznap` itself doesn't have any configuration.
Everything is driven by zfs _properties_.

### Setup ZFS datasets

Each dataset that is to be snapshotted must have two properties set:

  - `com.sun:auto-snapshot=true`
  - `com.sun.auto-snapshot:${label}=<true|(integer)>`

`${label}` is a keyword described above. The vaule of the _label_ property must
be either `true` or an integer greater than zero.

`true` means the dataset will participate in the labelled snapshot frequency
group with **default** retention policy (see below).

An Integer means that the dataset will participate as above but with **custom**
retention policy with the specified number.

### Retention policy

Only a limited number of snapshots is kept per each dataset and frequency
group. The number of snapshots is determined by _retention policy_.

**DEFAULT** retention policy is set as follows.
  - frequent = 4
  - hourly = 48
  - daily = 14
  - weekly = 8
  - monthly = 12

These vaules are (currently) is hardcoded.

**CUSTOM** retention policy means the number of snapshots in the frequency
group is set by the `com.sun:auto-snapshot:${label}` property.

It only makes sense to set the vaule to anything above 0.

When set to `0`, all snapshots in the group will be destroyed.

When set to anything else then `true` or a positive integer, the dataset will
**not** participate in the frequency group and `eznap` will ignore it within
the group. Any possible snapshots are ignored, too.


## Usage

First make sure to set the properties on all your datasets that you wish to
snapshot:

```
zfs set -o com.sun:auto-snapshot=true -o com.sun:auto-snapshot:hourly=8 tank/dataset0
zfs set -o com.sun:auto-snapshot=true -o com.sun:auto-snapshot:daily=true/dataset0

zfs set -o com.sun:auto-snapshot=true -o com.sun:auto-snapshot:frequent=true tank/dataset1

...

```

The suite includes systemd timers for each label. To enable `eznap`, enable
the apropriate timers you whant to be active:

```
systemctl enable eznap-frequent.timer
systemctl enable eznap-daily.timer
...
```

Whenever `eznap <label>` is executed, new snapshots will be created for the
`<label>` group and old snapshots will be destroyed in the group if any exist.

That's it!


