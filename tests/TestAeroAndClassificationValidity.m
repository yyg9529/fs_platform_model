classdef TestAeroAndClassificationValidity < matlab.unittest.TestCase
    %TESTAEROANDCLASSIFICATIONVALIDITY Fail-closed screening contracts.

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            oldPath = path;
            addpath(genpath(projectRoot));
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function missingNominalReferenceIsNotZeroLoss(testCase)
            caseDef = build_case_2026_target();
            caseDef.aero.nominalRef = struct();
            caseDef.targets.maxAeroLossPct = 1e6;
            caseDef.targets.maxFrontShareMigrationPct = 1e6;

            results = run_case(caseDef);

            testCase.verifyFalse(results.aero.nominalReferenceValid);
            testCase.verifyTrue(isnan(results.aero.lossPct));
            testCase.verifyFalse(results.flags.aeroPlatformPass);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
        end

        function nonconvergedPointIsNotEvaluated(testCase)
            caseDef = build_case_2026_target();
            caseDef.solver.maxIter = 1;
            caseDef.solver.tol = 1e-20;
            caseDef.targets.maxAeroLossPct = 1e6;
            caseDef.targets.maxFrontShareMigrationPct = 1e6;

            results = run_case(caseDef);

            testCase.verifyFalse(results.flags.converged);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
            testCase.verifyEqual(results.flags.mapClassQuasiStaticLabel, "Not Evaluated");
        end

        function clampedAeroMapIsNotEvaluatedAtSpeed(testCase)
            caseDef = build_case_2026_target();
            caseDef.ref.hAeroF0 = 1.0;
            caseDef.ref.hAeroR0 = 1.0;
            caseDef.targets.maxAeroLossPct = 1e6;
            caseDef.targets.maxFrontShareMigrationPct = 1e6;

            results = run_case(caseDef);

            testCase.verifyTrue(results.flags.mapClampedAny);
            testCase.verifyFalse(results.flags.aeroStateValid);
            testCase.verifyFalse(results.flags.aeroPlatformPass);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
        end

        function bundledTargetIsMarkedAsSyntheticAndUnreachable(testCase)
            results = run_case(build_case_2026_target());

            testCase.verifyEqual(results.aero.evidenceStatus, 'synthetic_demo');
            testCase.verifyFalse(results.aero.engineeringEvidenceReady);
            testCase.verifyFalse(results.aero.targetLossReachableWithMap);
            testCase.verifyTrue(results.flags.analysisReady, ...
                'A valid calculation must remain analyzable even when a design target fails.');
            testCase.verifyFalse(results.flags.feasible);
            testCase.verifyGreaterThan(results.aero.minimumPossibleLossPct, ...
                results.inputs.targets.maxAeroLossPct);
        end

        function bundledDataLoadStatusIsAuditable(testCase)
            results = run_case(build_case_2025_baseline());

            testCase.verifyEqual(results.aero.mapLoadStatus, 'loaded');
            testCase.verifyEqual(results.aero.nominalLoadStatus, 'loaded');
            testCase.verifyEmpty(results.aero.mapLoadMessage);
            testCase.verifyEmpty(results.aero.nominalLoadMessage);
        end

        function classificationRequiresAtLeastOneAeroCriterion(testCase)
            caseDef = build_case_2026_target();
            caseDef.targets.maxAeroLossPct = [];
            caseDef.targets.maxFrontShareMigrationPct = [];

            results = run_case(caseDef);

            testCase.verifyTrue(results.flags.analysisReady);
            testCase.verifyFalse(results.aero.criteriaDefined);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyFalse(results.flags.aeroPlatformPass);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
        end

        function balanceCriterionRequiresProvidedFrontShareReference(testCase)
            caseDef = build_case_2026_target();
            caseDef.targets.maxAeroLossPct = [];
            caseDef.targets.maxFrontShareMigrationPct = 100;
            caseDef.aero.nominalRef = rmfield(caseDef.aero.nominalRef, ...
                'frontShareNominal');

            results = run_case(caseDef);

            testCase.verifyTrue(results.flags.analysisReady);
            testCase.verifyFalse(results.aero.balanceEvaluable);
            testCase.verifyFalse(results.aero.nominalReferenceValid);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyEqual(results.flags.mapClassQuasiStatic, -1);
        end

        function nominalReferenceIsNotExtrapolated(testCase)
            caseDef = build_case_2026_target();
            caseDef.aero.nominalRef = struct( ...
                'VGrid', [0; 1], ...
                'FzNominal', [0; 100], ...
                'frontShareNominal', [0.5; 0.5]);

            results = run_case(caseDef);

            testCase.verifyFalse(results.aero.nominalReference.speedInRange);
            testCase.verifyFalse(results.aero.nominalReferenceValid);
            testCase.verifyTrue(isnan(results.aero.lossPct));
            testCase.verifyFalse(results.flags.classificationValid);
        end

        function engineeringReadinessRemainsFailClosed(testCase)
            caseDef = build_case_2026_target();
            caseDef.man.V = 0;
            caseDef.man.ax = 0;
            caseDef.man.ay = 0;
            caseDef.rules.enforceRules = false;

            zeroSpeedResult = run_case(caseDef);
            testCase.verifyFalse(zeroSpeedResult.aero.aeroLossEvaluable);
            testCase.verifyFalse(zeroSpeedResult.targets.aeroLossPass);
            testCase.verifyFalse(zeroSpeedResult.flags.designPass);
            testCase.verifyFalse(zeroSpeedResult.flags.classificationValid);

            caseDef.targets.enforceTargets = false;
            caseDef.aero.evidenceStatus = 'validated';
            caseDef.aero.mapSource = 'controlled_map_record';
            caseDef.aero.nominalSource = 'controlled_nominal_record';
            caseDef.aero.mapLoadStatus = 'loaded';
            caseDef.aero.nominalLoadStatus = 'loaded';

            results = run_case(caseDef);

            testCase.verifyTrue(results.flags.platformFeasible);
            testCase.verifyEqual(results.flags.feasible, ...
                results.flags.platformFeasible);
            testCase.verifyFalse(results.flags.engineeringReady);
            testCase.verifyEqual(results.flags.engineeringReadinessStatus, ...
                'not_ready_model_scope');
        end

        function ruleConstraintsHaveClauseEvidence(testCase)
            results = run_case(build_case_2025_baseline());

            testCase.verifyEqual(results.rules.staticGroundClearanceEvidenceStatus, ...
                'verified_public_rule');
            testCase.verifyEqual(results.rules.staticGroundClearanceClause, 'T2.2.1');
            testCase.verifyEqual(results.rules.travelEvidenceStatus, ...
                'verified_public_rule');
            testCase.verifyEqual(results.rules.travelConstraintClause, 'T2.5.1');
            testCase.verifyNotEmpty(results.rules.staticGroundClearanceSource);
        end

        function returnOnErrorKeepsValiditySchema(testCase)
            caseDef = build_case_2025_baseline();
            caseDef.veh.tf = 0;
            results = run_case(caseDef, struct('returnOnError', true));

            testCase.verifyTrue(results.flags.badInput);
            testCase.verifyFalse(results.flags.analysisReady);
            testCase.verifyFalse(results.flags.engineeringReady);
            testCase.verifyFalse(results.flags.classificationValid);
            testCase.verifyTrue(isfield(results.aero, 'evidenceStatus'));
            testCase.verifyTrue(isfield(results.rules, 'travelConstraintClause'));
            testCase.verifyTrue(isfield(results.debug, 'lastNormalizedResidual'));
            testCase.verifyTrue(isfield(results.corners, 'FzAntiRollBar'));
            testCase.verifyTrue(isfield(results.tire, 'utilization'));
        end

        function nonmonotonicAeroGridIsRejected(testCase)
            caseDef = build_case_2025_baseline();
            caseDef.aero.mapData.hfGrid(2) = caseDef.aero.mapData.hfGrid(1);

            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function infiniteAeroTableValueIsRejected(testCase)
            caseDef = build_case_2025_baseline();
            caseDef.aero.mapData.CzTable(1) = inf;

            testCase.verifyError(@() run_case(caseDef), 'run_case:ValidationFailed');
        end

        function malformedAeroProvenanceIsRejected(testCase)
            caseDef = build_case_2025_baseline();
            caseDef.aero.mapLoadStatus = struct('spoofed', true);

            testCase.verifyError(@() run_case(caseDef), ...
                'run_case:ValidationFailed');
        end
    end
end
