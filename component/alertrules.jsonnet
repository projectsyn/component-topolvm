local alertpatching = import 'lib/alert-patching.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.topolvm;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');

assert
  std.member(inv.applications, 'openshift4-monitoring') ||
  isOpenshift != true
  : 'Component openshift4-monitoring is not available';

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
          alert: 'SYN_TopoLVMVolumeGroupAlmostFull',
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
            syn: 'true',
            syn_component: 'topolvm',
          },
        },
        {
          alert: 'SYN_TopoLVMVolumeGroupNearFull',
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
            syn: 'true',
            syn_component: 'topolvm',
          },
        },
      ],
    },
  ],
};

// Define outputs below
if isOpenshift then
  {
    '20_rules': kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'syn-topolvm-rules') {
      metadata+: {
        namespace: params.namespace,
      },
      spec: {
        groups: std.filter(
          function(it) it != null,
          [
            local r = alertpatching.filterPatchRules(g, ignore_alerts);
            if std.length(r.rules) > 0 then r
            for g in alertrules.groups
          ]
        ),
      },
    },
  }
else
  std.trace(
    'Alert handling library not available, not deploying alertrules',
    {}
  )
