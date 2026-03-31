function test_tire_table_disabled_keeps_v104_behavior()
%TEST_TIRE_TABLE_DISABLED_KEEPS_V104_BEHAVIOR 关闭轮胎代理层时保持 V1.0.4 行为。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseBase = build_case_2026_target();
caseBase.rules.enforceRules = false;
caseBase.targets.enforceTargets = false;
caseBase.tire.mode = 'fixed';
caseBase.tire.ktFront = 220000;
caseBase.tire.ktRear = 240000;

resBase = run_case(caseBase);

caseOff = caseBase;
caseOff.tire.forceModel.enable = false;
caseOff.tire.forceModel.data = build_demo_tire_force_tables();
caseOff.tireOp.alphaFront = 9.0;
caseOff.tireOp.kappaFront = -0.08;
resOff = run_case(caseOff);

assert(abs(resBase.state.z - resOff.state.z) < 1e-12, 'Disabled tire layer must not change z.');
assert(abs(resBase.state.theta - resOff.state.theta) < 1e-12, 'Disabled tire layer must not change theta.');
assert(abs(resBase.state.phi - resOff.state.phi) < 1e-12, 'Disabled tire layer must not change phi.');
assert(abs(resBase.aero.Fz - resOff.aero.Fz) < 1e-9, 'Disabled tire layer must not change aero load.');
assert(abs(resBase.clearance.hDynamicMin - resOff.clearance.hDynamicMin) < 1e-12, ...
    'Disabled tire layer must not change clearance.');
assert(abs(resBase.rules.minEffectiveTotalTravel - resOff.rules.minEffectiveTotalTravel) < 1e-12, ...
    'Disabled tire layer must not change effective travel.');
assert(strcmpi(resBase.tire.mode, resOff.tire.mode), 'Legacy tire.mode output must stay unchanged.');
assert(~resOff.flags.tireForceModelEnabled, 'Disabled tire layer should keep tireForceModelEnabled=false.');

fprintf('[PASS] test_tire_table_disabled_keeps_v104_behavior\n');
end
