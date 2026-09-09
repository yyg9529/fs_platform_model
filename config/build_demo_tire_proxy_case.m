function caseDef = build_demo_tire_proxy_case()
%BUILD_DEMO_TIRE_PROXY_CASE Build the synthetic tire-proxy demo case.
% The generated tire tables are synthetic and are suitable only for
% demonstrations and software regression, not engineering sign-off.

caseDef = build_case_2026_target();
caseDef.rules.enforceRules = false;
caseDef.targets.enforceTargets = false;

caseDef.tire.mode = 'fixed';
caseDef.tire.ktFront = 220000;
caseDef.tire.ktRear = 240000;

caseDef.tire.forceModel.enable = true;
caseDef.tire.forceModel.sourceType = 'table_struct';
caseDef.tire.forceModel.data = build_demo_tire_force_tables();
caseDef.tire.forceModel.mode = 'pure_plus_combined_proxy';
caseDef.tire.forceModel.outOfRangePolicy = 'warn_clamp';
caseDef.tire.forceModel.includeAligningMoment = true;

caseDef.tireOp.mode = 'direct';
caseDef.tireOp.alpha = 0.0;
caseDef.tireOp.kappa = 0.0;
caseDef.tireOp.gamma = [-2; -2; -1; -1];
caseDef.tireOp.pressure = 83000;
caseDef.tireOp.alphaUnit = 'deg';
caseDef.tireOp.gammaUnit = 'deg';
caseDef.tireOp.kappaUnit = 'ratio';
caseDef.tireOp.pressureUnit = 'Pa';
caseDef.tireOp.scan.enable = false;
caseDef.tireOp.scan.field = '';
caseDef.tireOp.scan.values = [];
caseDef.tireOp.scan.unit = '';
caseDef.tireOp.scan.applyMode = 'all_corners';
caseDef.tireOp.scan.notes = 'synthetic demo helper default';
end
