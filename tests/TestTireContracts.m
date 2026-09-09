classdef TestTireContracts < matlab.unittest.TestCase
    %TESTTIRECONTRACTS Explicit tire-proxy validity and metric semantics.

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            oldPath = path;
            addpath(genpath(projectRoot));
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function unsupportedPressureScanFailsExplicitly(testCase)
            caseDef = build_test_tire_proxy_case();
            caseDef.tireOp.scan.enable = true;
            caseDef.tireOp.scan.field = 'pressure';
            caseDef.tireOp.scan.values = [75, 83, 90];
            caseDef.tireOp.scan.unit = 'kPa';

            lastwarn('');
            results = run_case(caseDef);
            [~, warningId] = lastwarn;

            testCase.verifyEqual(warningId, 'run_case:TireEvaluationFailed');
            testCase.verifyTrue(results.flags.tireEvalFailed);
            testCase.verifyFalse(results.flags.analysisReady);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
            testCase.verifyThat(results.debug.tireForceModelError, ...
                matlab.unittest.constraints.ContainsSubstring('pressure'));
        end

        function pressureMismatchFailsInsteadOfProducingFalseSensitivity(testCase)
            caseDef = build_test_tire_proxy_case();
            caseDef.tireOp.pressure = 90;
            caseDef.tireOp.pressureUnit = 'kPa';

            lastwarn('');
            results = run_case(caseDef);
            [~, warningId] = lastwarn;

            testCase.verifyEqual(warningId, 'run_case:TireEvaluationFailed');
            testCase.verifyTrue(results.flags.tireEvalFailed);
            testCase.verifyFalse(results.flags.analysisReady);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
            testCase.verifyThat(results.debug.tireForceModelError, ...
                matlab.unittest.constraints.ContainsSubstring('pressure'));
        end

        function combinedUtilizationUsesSuperellipseRadius(testCase)
            proxyCfg = struct('exponent', 2, 'type', 'friction_ellipse');
            proxy = evaluate_tire_combined_proxy(60, 80, 100, 100, proxyCfg);

            testCase.verifyEqual(proxy.utilizationDemand, 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(proxy.utilization, 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(proxy.peakMargin, 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(proxy.constraintValue, 1, 'AbsTol', 1e-12);
        end

        function sublimitCombinedUtilizationIsRadial(testCase)
            proxyCfg = struct('exponent', 2, 'type', 'friction_ellipse');
            proxy = evaluate_tire_combined_proxy(30, 40, 100, 100, proxyCfg);

            testCase.verifyEqual(proxy.utilizationDemand, 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(proxy.peakMargin, 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(proxy.constraintValue, 0.25, 'AbsTol', 1e-12);
        end

        function errorOutOfRangePolicyPropagates(testCase)
            caseDef = build_test_tire_proxy_case();
            caseDef.tire.forceModel.outOfRangePolicy = 'error';
            caseDef.tireOp.alpha = 30;

            testCase.verifyError(@() run_case(caseDef), ...
                'evaluate_tire_table_model:OutOfRangeError');
        end

        function balanceUsesTheSameRadialUtilizationDefinition(testCase)
            caseDef = build_test_tire_proxy_case();
            caseDef.tireOp.alpha = 5;
            caseDef.tireOp.kappa = -0.05;

            results = run_case(caseDef);

            testCase.verifyEqual(results.tire.balance.frontUtilization, ...
                max(results.tire.utilization.requested(1:2)), 'AbsTol', 1e-12);
            testCase.verifyEqual(results.tire.balance.rearUtilization, ...
                max(results.tire.utilization.requested(3:4)), 'AbsTol', 1e-12);
            if results.flags.tireOutOfRange
                testCase.verifyFalse(results.flags.analysisReady);
                testCase.verifyFalse(results.flags.classificationValid);
                testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
            end
        end


        function unsupportedCombinedProxyTypeIsRejected(testCase)
            proxyCfg = struct('exponent', 2, 'type', 'combined_utilization_proxy');

            testCase.verifyError(@() evaluate_tire_combined_proxy(30, 40, 100, 100, proxyCfg), ...
                'evaluate_tire_combined_proxy:UnsupportedType');
            proxyCfg = struct('exponent', 0.5, 'type', 'friction_ellipse');
            testCase.verifyError(@() evaluate_tire_combined_proxy(30, 40, 100, 100, proxyCfg), ...
                'evaluate_tire_combined_proxy:BadExponent');
        end
    end
end
