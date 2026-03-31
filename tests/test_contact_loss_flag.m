function test_contact_loss_flag()
%TEST_CONTACT_LOSS_FLAG Fz<=0 时 contactLostAny 正确置位。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

casePlatform = build_test_tire_proxy_case();
casePlatform.tire.forceModel.enable = false;
platformRes = run_case(casePlatform);

caseEval = build_test_tire_proxy_case();
tireData = load_tire_table_data(caseEval);
op = normalize_tire_operating_points(caseEval, platformRes, tireData);
op.Fz(1) = 0.0;

evalOut = evaluate_tire_table_model(caseEval, tireData, op);

assert(evalOut.validity.contactLostAny, 'Expected contactLostAny=true when any Fz<=0.');
assert(~evalOut.validity.validFz(1), 'Expected invalid Fz flag at lifted corner.');
assert(isnan(evalOut.Fy(1)) && isnan(evalOut.Fx(1)), 'Lifted corner should not return normal tire forces.');

fprintf('[PASS] test_contact_loss_flag\n');
end
