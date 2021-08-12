local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.topolvm;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('topolvm', params.namespace);

{
  topolvm: app,
}
