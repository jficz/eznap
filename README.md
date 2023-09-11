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

  - frequent (evey 15min by default)
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

  - `com.sun:auto-snapshot:<label>=false`

To enable a label explicitly (like when the property is inherited):

  - `com.sun:auto-snapshot:<label>=true`

To enable a label with a _custom retention policy_:

  - `com.sun:auto-snapshot:<label>=<integer>`

`<label>` is a keyword described above (`frequent`, `daily`, etc.)

Setting the property to `0` is permitted and will delete all snapshots with that label.


### Custom frequet snapshots frequency

The frequency of the `frequent` snapshots can be set per dataset setting the property `cz.jfi.eznap:frequency`
to a positive integer. The integer represents minutes. You need to adjust your timer triggers to
have the same or better resolution than your frequent frequency. See _Usage_ below.

Setting the property to `0` is not supported but with the current code base it will result in
triggering the `frequent` label on every run of the `trigger`, equalling the frequency to the
trigger timer.


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

For example, use `com.sun:auto-snapshot:daily=7` to keep only 7 days worth 
of daily snapshots of the dataset.

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

zfs set -o cz.jfi.eznap:frequency=5 tank/data/important_database

...

```

Manual invocation:
```bash
$ eznap <label | "trigger">
```
`<label>` will process the label (`daily`, `weekly`, ...) and create (and delete) snapshot
with that label. *Warning*: running a label directly will result in its immediate application,
regardless of the real time schedule! This means that if you, for instance, run `eznap weekly`
three times in a row, you will end up with three snapshots called `weekly` and you will lose
all weekly snapshots below the retention threshold.

It is recommended to run labels directly _only_ as part of testing or debugging, otherwise
they should only be run by an apropriately timed cron job, timer, or other scheduler.

`trigger` will process all labels according to their schedules. This operation invokes
`eznap`'s internal scheduling logic which will trigger all labels according to their schedules.
It is safe to run `trigger` many times over, the labels will not be triggered unless their
schedule is due.


Simple cron, use `eznap`'s builtin scheduling and triggering. This is the recommended approach
when using cron:
```cron
*/5 * * * * eznap trigger
```

Custom cron, if you don't want to use `eznap`'s internal scheduling, you can schedule all labels manually:
```cron
*/15 * * * *  eznap frequent
@hourly       eznap hourly
@daily        eznap daily
@weekly       eznap weekly
@monthly      eznap montly
```

Systemd timer:
```
systemctl enable --now eznap.timer
```
This timer triggers `eznap` every 15 minutes by default which is optimal for the default `frequent` frequency.
If you change your `frequent` frequency (see above) to anything else than 15 minutes, make sure that the
timer is triggered according to that frequency. You can use the `eznap@.timer` template for that:
```
systemctl enable --now eznap@5min.timer
```


The user executing `eznap` must have the rights to create and delete snapshots,
such as by `zfs-allow(8)`, or being root.

That's it!


