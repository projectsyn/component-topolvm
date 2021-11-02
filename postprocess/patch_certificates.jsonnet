local com = import 'lib/commodore.libjsonnet';
// local inv = com.inventory();
// local params = inv.parameters.topolvm;

local certificates_file = std.extVar('output_path') + '/certificates.yaml';
local certificates = com.yaml_load_all(certificates_file);

{
  certificates: [
    cert { spec+: { duration: '8760h0m0s' } }
    for cert in certificates
  ],
}
