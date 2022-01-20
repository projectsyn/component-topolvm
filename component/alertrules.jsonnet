local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.topolvm;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');

assert
  std.member(inv.applications, 'rancher-monitoring') ||
  std.member(inv.applications, 'openshift4-monitoring')
  : 'Neither rancher-monitoring nor openshift4-monitoring is available';

// Function to process an array which supports removing previously added
// elements by prefixing them with ~
local render_array(arr) =
  // extract real value of array entry
  local realval(v) = std.lstripChars(v, '~');
  // Compute whether each element should be included by keeping track of
  // whether its last occurrence in the input array was prefixed with ~ or
  // not.
  local val_state = std.foldl(
    function(a, it) a + it,
    [
      { [realval(v)]: !std.startsWith(v, '~') }
      for v in arr
    ],
    {}
  );
  // Return filtered array containing only elements whose last occurrence
  // wasn't prefixed by ~.
  std.filter(
    function(val) val_state[val],
    std.objectFields(val_state)
  );

// Upstream alerts to ignore
local ignore_alerts = std.set(
  // Add set of alerts that should be ignored from `params.ignore_alerts`
  render_array(params.ignore_alerts)
);

/* FROM HERE: should be provided as library function by
 * rancher-/openshift4-monitoring */
// We shouldn't be expected to care how rancher-/openshift4-monitoring
// implement alert managmement and patching, instead we should be able to
// reuse their functionality as a black box to make sure our alerts work
// correctly in the environment into which we're deploying.

local global_alert_params =
  if isOpenshift then
    inv.parameters.openshift4_monitoring.alerts
  else
    inv.parameters.rancher_monitoring.alerts;

local filter_patch_rules(g) =
  // combine our set of alerts to ignore with the monitoring component's
  // set of ignoreNames.
  local ignore_set = std.set(global_alert_params.ignoreNames + ignore_alerts);
  g {
    rules: std.filter(
      // Filter out unwanted rules
      function(rule)
        // Drop rules which are in the ignore_set
        !std.member(ignore_set, rule.alert),
      super.rules
    ),
  };

/* TO HERE */

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

{
  '20_rules': kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'syn-topolvm-rules') {
    metadata+: {
      namespace: params.namespace,
    },
    spec: {
      groups: std.filter(
        function(it) it != null,
        [
          local r = filter_patch_rules(g);
          if std.length(r.rules) > 0 then r
          for g in alertrules.groups
        ]
      ),
    },
  },
}
