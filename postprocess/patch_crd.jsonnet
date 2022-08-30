local com = import 'lib/commodore.libjsonnet';

local crd_file = std.extVar('output_path') + '/topolvm.cybozu.com_logicalvolumes.yaml';
local crd = com.yaml_load_all(crd_file);

{
  'topolvm.cybozu.com_logicalvolumes': std.filter(function(it) it != null, crd),
}
