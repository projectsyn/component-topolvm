local com = import 'lib/commodore.libjsonnet';
// The hiera parameters for the component
local params = com.inventory().parameters.topolvm;

local topo_nodes = com.yaml_load_all(std.extVar('output_path') + '/node/daemonset.yaml')[0];
local topo_lvmd = com.yaml_load_all(std.extVar('output_path') + '/lvmd/daemonset.yaml')[0];

{
  'node/daemonset': topo_nodes {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': '2',
      },
    },
  },
  [if params.helm_values.lvmd.managed then 'lvmd/daemonset']: topo_lvmd {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': '1',
      },
    },
  },
}
