function results = invalidate_decision_state(results, reason)
%INVALIDATE_DECISION_STATE Fail closed after an enabled layer is invalid.
% Platform feasibility remains available as a platform-only diagnostic, but
% global analysis/classification and map decisions become Not Evaluated.

if nargin < 2
    reason = 'An enabled evaluation layer is invalid.';
end

results.flags.analysisReady = false;
results.flags.classificationValid = false;
results.flags.engineeringReady = false;
results.flags.decisionInvalidReason = char(string(reason));
results.flags.aeroPlatformPass = false;
results.flags.scrapePassQuasiStatic = false;
results.flags.scrapePassBumpAdjusted = false;
results.flags.mapClassQuasiStatic = -1;
results.flags.mapClassQuasiStaticLabel = "Not Evaluated";
results.flags.mapClassQuasiStaticColor = [0.25, 0.25, 0.25];
results.flags.mapClassBumpAdjusted = -1;
results.flags.mapClassBumpAdjustedLabel = "Not Evaluated";
results.flags.mapClassBumpAdjustedColor = [0.25, 0.25, 0.25];

if isfield(results, 'aero') && isstruct(results.aero)
    results.aero.evaluationValid = false;
end
end
