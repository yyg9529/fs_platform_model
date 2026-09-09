classdef TestSolverAndSweepContracts < matlab.unittest.TestCase
    %TESTSOLVERANDSWEEPCONTRACTS Solver and parameter-grid safety contracts.

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            oldPath = path;
            addpath(genpath(projectRoot));
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function smallNewtonStepWithLargeResidualIsNotConverged(testCase)
            caseDef = build_case_2026_target();
            caseDef.man.V = 0;
            caseDef.man.ax = 0;
            caseDef.man.ay = 8;
            [caseDef, report] = validate_case_struct(caseDef);
            testCase.assertFalse(report.badInput, strjoin(report.messages, ' | '));
            caseDef = preprocess_case(caseDef);

            % Deliberately remove every roll-restoring path after validation.
            caseDef.derived.geom.V(:, 3) = 0;
            caseDef.sus.kArbF = 0;
            caseDef.sus.kArbR = 0;
            caseDef.solver.useAeroIter = true;

            solveOut = solve_equilibrium(caseDef);

            testCase.verifyFalse(solveOut.converged);
            testCase.verifyGreaterThan(norm(solveOut.lastResidual, 2), caseDef.solver.tol);
        end

        function nonpositiveTrackWidthIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.veh.tf = 0;
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function nonfiniteRollCenterIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.veh.hRCf = nan;
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function inconsistentWheelbaseSplitIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.veh.lf = 0.9 * caseDef.veh.L;
            caseDef.veh.lr = 0.9 * caseDef.veh.L;
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function outOfContractAntiFractionIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.longi.antiDiveF = 1.1;
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function outOfContractBiasIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.longi.brakeBiasF = -0.1;
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function nonfiniteDragHeightIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.aero.hDrag = inf;
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function malformedInputsFailClosedInSingleAndBatch(testCase)
            badAero = build_case_2026_target();
            badAero.aero = 5;
            resultAero = run_case(badAero, struct('returnOnError', true));
            testCase.verifyTrue(resultAero.flags.badInput);
            testCase.verifyEqual(resultAero.debug.failureStage, 'validation');
            testCase.verifyFalse(resultAero.flags.tireEvalFailed);
            testCase.verifyEqual(resultAero.flags.mapClassQuasiStatic, -1);

            badScalar = build_case_2026_target();
            badScalar.targets.minDynamicClearance = struct('bad', true);
            resultScalar = run_case(badScalar, struct('returnOnError', true));
            testCase.verifyTrue(resultScalar.flags.badInput);
            testCase.verifyEqual(resultScalar.debug.failureStage, 'validation');

            badBatch = build_case_2026_target();
            badBatch.sus = 5;
            goodBatch = build_case_2026_target();
            batch = run_batch({badBatch, goodBatch}, struct('returnOnError', true));
            testCase.verifyEqual(batch.nCases, 2);
            testCase.verifyTrue(batch.resultsList{1}.flags.badInput);
            testCase.verifyTrue(isnan(batch.summaryTable.FrontSpring(1)));
            testCase.verifyTrue(batch.resultsList{2}.flags.converged);
        end

        function inconsistentWheelRateOverrideIsRejected(testCase)
            caseDef = build_case_2026_target();
            caseDef.sus.kw = caseDef.sus.ks .* (caseDef.sus.mr .^ 2);
            caseDef.sus.ks(1:2) = 2 * caseDef.sus.ks(1:2);
            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function scaledResidualEvidenceIsExposed(testCase)
            caseDef = build_case_2026_target();
            results = run_case(caseDef);

            testCase.verifyTrue(isfield(results.debug, 'normalizedResidualHistory'));
            testCase.verifyTrue(isfield(results.debug, 'lastNormalizedResidual'));
            testCase.verifyLessThan(results.debug.lastNormalizedResidual, ...
                caseDef.solver.tol);
        end

        function tireRangeDeclaresCorrelatedDiagonalAssumption(testCase)
            caseDef = build_case_2025_baseline();
            caseDef.tire.mode = 'range';
            results = run_case(caseDef);

            testCase.verifyEqual(results.range.assumption, ...
                'correlated_diagonal_front_rear');
            testCase.verifyFalse(results.range.isCartesianEnvelope);
            testCase.verifyEqual(numel(results.range.band.analysisReady), 3);
            testCase.verifyEqual(numel(results.range.band.classificationValid), 3);
            testCase.verifyFalse(results.flags.engineeringReadyRangeAny);
            testCase.verifyEqual(results.range.low.rangeScenario.label, 'low');
        end

        function submittedAndNormalizedInputsRemainDistinct(testCase)
            caseDef = rmfield(build_case_2025_baseline(), 'solver');
            results = run_case(caseDef);

            testCase.verifyFalse(isfield(results.inputsSubmitted, 'solver'));
            testCase.verifyTrue(isfield(results.inputs, 'solver'));
            testCase.verifyTrue(isfield(results.inputsRaw, 'solver'));
        end

        function nonsquareSpringSweepPreservesGridCoordinates(testCase)
            caseDef = build_case_2025_baseline();
            caseDef.man.V = 0;
            caseDef.man.ax = 0;
            caseDef.man.ay = 0;
            caseDef.solver.useAeroIter = false;
            caseDef.rules.enforceRules = false;
            caseDef.targets.enforceTargets = false;
            sweepDef = struct( ...
                'frontSpringSweep', [10000, 20000], ...
                'rearSpringSweep', [30000, 40000, 50000]);

            sweepOut = run_spring_sweep(caseDef, sweepDef, struct());

            for iRear = 1:3
                for iFront = 1:2
                    result = sweepOut.resultGrid{iRear, iFront};
                    testCase.verifyEqual(mean(result.inputs.sus.ks(1:2)), ...
                        sweepOut.frontSpringValues(iFront));
                    testCase.verifyEqual(mean(result.inputs.sus.ks(3:4)), ...
                        sweepOut.rearSpringValues(iRear));
                end
            end
        end
    end
end
