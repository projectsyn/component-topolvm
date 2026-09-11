local alertpatching = import 'lib/alert-patching.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.topolvm;

// Upstream alerts to ignore
local ignore_alerts = std.set(
  // Add set of alerts that should be ignored from `params.ignore_alerts`
  com.renderArray(params.ignore_alerts)
);

local alertrules = {
  groups: [
    {
      name: 'topolvm-alert.rules',
      rules: [
        {
          alert: 'TopoLVMVolumeGroupAlmostFull',
          annotations: {
            description: |||
              Utilization of volume group {{ $labels.device_class }}
              has crossed 95% on host {{ $labels.node }}.
            |||,
            message: 'LVM volume group is almost full.',
            runbook_url: 'https://hub.syn.tools/topolvm/runbooks/TopoLVMVolumeGroupAlmostFull.html',
            severity_level: 'warning',
            storage_type: 'topolvm',
          },
          expr: '(topolvm_volumegroup_available_bytes / topolvm_volumegroup_size_bytes) <= 0.05',
          'for': '10m',
          labels: {
            severity: 'warning',
          },
        },
        {
          alert: 'TopoLVMVolumeGroupNearFull',
          annotations: {
            description: |||
              Utilization of volume group {{ $labels.device_class }}
              has crossed 85% on host {{ $labels.node }}.
            |||,
            message: 'LVM volume group is nearing full.',
            runbook_url: 'https://hub.syn.tools/topolvm/runbooks/TopoLVMVolumeGroupNearFull.html',
            severity_level: 'warning',
            storage_type: 'topolvm',
          },
          expr: '(topolvm_volumegroup_available_bytes / topolvm_volumegroup_size_bytes) <= 0.15',
          'for': '1h',
          labels: {
            severity: 'warning',
          },
        },
      ],
    },
  ],
};

local groups = std.filter(
  function(g) std.length(g.rules) > 0,
  [
    alertpatching.filterPatchRules(g, ignoreNames=ignore_alerts)
    for g in alertrules.groups
  ]
);

local has_monitoring = std.member(inv.applications, 'prometheus') || std.member(inv.applications, 'openshift4-monitoring');
local has_alerts = std.length(groups) > 0;

// Define outputs below
{
  [if has_monitoring && has_alerts then '20_rules']:
    kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'syn-topolvm-rules') {
      metadata+: {
        namespace: params.namespace,
      },
      spec: {
        groups: groups,
      },
    },
}
