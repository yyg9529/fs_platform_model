function test_shock_length_derived_metrics()
%TEST_SHOCK_LENGTH_DERIVED_METRICS shock 长度派生量与 off 模式刚度核验。
% 功能说明:
%   1) 验证 shock 长度派生公式。
%   2) 验证 tire.mode='off' 时 keq=kw。

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

caseDef = build_case_2025_baseline();
caseDef.tire.mode = 'off';
caseDef.sus.shockLenExtended = 0.320;   % 标量输入
caseDef.sus.shockLenCompressed = 0.260; % 标量输入
caseDef.sus.shockLenStatic = 0.290;     % 标量输入

[caseDef, report] = validate_case_struct(caseDef);
assert(~report.badInput, 'Validation should pass for scalar shock inputs.');

caseDef = preprocess_case(caseDef);

tol = 1e-12;
assert(all(abs(caseDef.sus.shockLenExtended - 0.320) < tol), 'Scalar expansion failed: shockLenExtended.');
assert(all(abs(caseDef.sus.shockLenCompressed - 0.260) < tol), 'Scalar expansion failed: shockLenCompressed.');
assert(all(abs(caseDef.sus.shockLenStatic - 0.290) < tol), 'Scalar expansion failed: shockLenStatic.');

expTotal = 0.320 - 0.260;
expStaticUsed = 0.320 - 0.290;
expCompAvail = 0.290 - 0.260;
expReboundAvail = 0.320 - 0.290;

assert(all(abs(caseDef.derived.susp.shockStrokeTotal - expTotal) < tol), 'shockStrokeTotal mismatch.');
assert(all(abs(caseDef.derived.susp.shockStrokeStaticUsed - expStaticUsed) < tol), 'shockStrokeStaticUsed mismatch.');
assert(all(abs(caseDef.derived.susp.shockCompAvail - expCompAvail) < tol), 'shockCompAvail mismatch.');
assert(all(abs(caseDef.derived.susp.shockReboundAvail - expReboundAvail) < tol), 'shockReboundAvail mismatch.');

assert(max(abs(caseDef.derived.stiff.keq - caseDef.derived.stiff.kw)) < tol, ...
    'tire.mode=off requires keq=kw.');

fprintf('[PASS] test_shock_length_derived_metrics\n');
end
