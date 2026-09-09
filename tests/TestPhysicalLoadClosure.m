classdef TestPhysicalLoadClosure < matlab.unittest.TestCase
    %TESTPHYSICALLOADCLOSURE Ground-contact load reconstruction contracts.

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            oldPath = path;
            addpath(genpath(projectRoot));
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function rollMomentIncludesElasticArbAndGeometricPaths(testCase)
            caseDef = build_case_2026_target();
            caseDef.man.V = 0;
            caseDef.man.ax = 0;
            caseDef.rules.enforceRules = false;
            caseDef.targets.enforceTargets = false;

            results = run_case(caseDef);
            y = results.inputs.derived.geom.V(:, 3);
            expected = caseDef.veh.m * caseDef.man.ay * caseDef.veh.hCG;

            testCase.verifyEqual(dot(y, results.corners.FzDynamic), expected, ...
                'AbsTol', 1e-8);
            testCase.verifyEqual(results.corners.FzDynamic, ...
                results.corners.FzElasticSpring + results.corners.FzAntiRollBar + ...
                results.corners.FzRollCenterGeometric + results.corners.FzAntiPitchGeometric, ...
                'AbsTol', 1e-10);
            testCase.verifyEqual(results.loads.ayTurn, caseDef.man.ay, 'AbsTol', 0);
            testCase.verifyEqual(results.loads.ayCartesian, -caseDef.man.ay, 'AbsTol', 0);
            testCase.verifyEqual(results.loads.ayConvention, ...
                'positive_left_turn_y_axis_positive_right');
            testCase.verifyEqual(sum(results.corners.FzAntiRollBar), 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(sum(results.corners.FzRollCenterGeometric), 0, 'AbsTol', 1e-12);
        end

        function pitchMomentIncludesAntiGeometryPath(testCase)
            caseDef = build_case_2026_target();
            caseDef.man.V = 0;
            caseDef.man.ay = 0;
            caseDef.rules.enforceRules = false;
            caseDef.targets.enforceTargets = false;

            results = run_case(caseDef);
            x = results.inputs.derived.geom.V(:, 2);
            expected = -caseDef.veh.m * caseDef.man.ax * caseDef.veh.hCG;

            testCase.verifyEqual(dot(x, results.corners.FzDynamic), expected, ...
                'AbsTol', 1e-8);
            testCase.verifyEqual(dot(x, results.corners.FzAntiPitchGeometric), ...
                results.loads.pitch.Mpitch_xDirect, 'AbsTol', 1e-10);
            testCase.verifyEqual(sum(results.corners.FzAntiPitchGeometric), 0, 'AbsTol', 1e-12);
        end

        function heaveAndGeneralizedContactLoadsClose(testCase)
            caseDef = build_case_2026_target();
            caseDef.rules.enforceRules = false;
            caseDef.targets.enforceTargets = false;

            results = run_case(caseDef);
            V = results.inputs.derived.geom.V;
            expected = [results.aero.Fz; ...
                results.loads.pitch.Mpitch_aero + results.loads.pitch.Mpitch_drag + ...
                    results.loads.pitch.Mpitch_xTotal; ...
                results.loads.roll.MrollTotal];

            testCase.verifyEqual(V' * results.corners.FzDynamic, expected, 'AbsTol', 1e-7);
            testCase.verifyEqual(results.corners.FzWheel, ...
                results.corners.FzStatic + results.corners.FzDynamic, 'AbsTol', 1e-12);
        end

        function axleBypassPathsMatchExactCornerVectors(testCase)
            caseDef = build_case_2026_target();
            caseDef.man.V = 0;
            caseDef.man.ax = 0;
            caseDef.rules.enforceRules = false;
            caseDef.targets.enforceTargets = false;

            results = run_case(caseDef);
            phi = results.state.phi;
            expectedArb = [ ...
                -caseDef.sus.kArbF * phi / caseDef.veh.tf; ...
                 caseDef.sus.kArbF * phi / caseDef.veh.tf; ...
                -caseDef.sus.kArbR * phi / caseDef.veh.tr; ...
                 caseDef.sus.kArbR * phi / caseDef.veh.tr];
            expectedRc = [ ...
                -caseDef.veh.m * caseDef.man.ay * caseDef.veh.wf_static * ...
                    caseDef.veh.hRCf / caseDef.veh.tf; ...
                 caseDef.veh.m * caseDef.man.ay * caseDef.veh.wf_static * ...
                    caseDef.veh.hRCf / caseDef.veh.tf; ...
                -caseDef.veh.m * caseDef.man.ay * (1-caseDef.veh.wf_static) * ...
                    caseDef.veh.hRCr / caseDef.veh.tr; ...
                 caseDef.veh.m * caseDef.man.ay * (1-caseDef.veh.wf_static) * ...
                    caseDef.veh.hRCr / caseDef.veh.tr];

            testCase.verifyEqual(results.corners.FzAntiRollBar, expectedArb, ...
                'AbsTol', 1e-10);
            testCase.verifyEqual(results.corners.FzRollCenterGeometric, expectedRc, ...
                'AbsTol', 1e-10);
        end

        function contactLossBlocksFeasibleResult(testCase)
            caseDef = build_case_2026_target();
            caseDef.man.V = 0;
            caseDef.man.ax = 0;
            caseDef.man.ay = 40;
            caseDef.rules.enforceRules = false;
            caseDef.targets.enforceTargets = false;
            caseDef.solver.strictTravelViolation = false;

            results = run_case(caseDef);

            testCase.verifyTrue(results.flags.contactLostAny);
            testCase.verifyFalse(results.flags.feasible);
            testCase.verifyFalse(results.flags.analysisReady);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
        end
    end
end
