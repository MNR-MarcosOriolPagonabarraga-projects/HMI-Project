# EEG Preprocessing Status

## Current Status
The codebase now implements the full preprocessing pipeline described in the assignment in `main.m` and the helper functions under `routines/`.

Pipeline order now matches the requested workflow:
1. Load the first 61 EEG channels and event matrix from each run.
2. Band-pass filter the continuous EEG from 0.3 to 70 Hz.
3. Reject bad channels automatically.
4. Optionally decimate the continuous EEG.
5. Re-reference the retained channels with common average reference (CAR).
6. Run ICA and remove components classified as artifacts by ICLabel.
7. Interpolate the rejected channels with spherical interpolation.
8. Extract baseline-corrected trials from -2.5 s to 6 s around each stimulus.
9. Reject bad trials using reaction-time rules and a +/-150 uV amplitude threshold.

## What Is Implemented
- `main.m` now loops through all subjects and runs, aggregates subject-level results, and saves outputs under `output/`.
- Bad-channel rejection was rewritten to be conservative by default:
  - rejection uses low channel correlation and clear variance outliers
  - MAD and kurtosis are still computed and stored as diagnostics
- Decimation is implemented as a configurable step through `decimation_factor`.
- Trial extraction is implemented directly from the `EEG.events` matrix.
- Trial rejection now follows the assignment rules:
  - reject trials with movement onset before 100 ms
  - reject trials with movement onset after 2 s
  - reject trials with missing movement onset (`0`)
  - reject channel-trials whose amplitude exceeds +/-150 uV
- Visualization helpers were added:
  - `routines/plot_preprocessing_steps.m`
  - `routines/plot_cz_erp_summary.m`

## Deliverables Mapping
- D1 bad channels:
  - `results.bad_channels`
  - `results.bad_channel_labels`
- D2 good-trial percentages:
  - `results.trial_masks`
  - `results.good_trial_percent`
  - `results.good_trial_percent_mean`
- D3 Cz averages and grand means:
  - `results.cz_average`
  - `results.grand_mean_cz`
  - `output/figures/cz_erp_summary.png`

Main outputs when `main.m` is executed:
- `output/preprocessing_results.mat`
- `output/figures/preprocessing_Sxx_Ryy.png` for configured diagnostic runs
- `output/figures/cz_erp_summary.png`

## Important Assumptions
- The project currently assumes:
  - `EEG.events(:, 1)` is the movement/event code
  - `EEG.events(:, 2)` is the stimulus sample
  - `EEG.events(:, 3)` is the physical movement onset sample
- A movement onset value of `0` is treated as an invalid onset and the trial is rejected.
- Only the first 61 channels are treated as EEG channels. Auxiliary channels are not used in the current preprocessing path.
- `decimation_factor` is set to `1` by default so the epoch length stays consistent with the assignment target of `4352` samples per trial.
- Only event codes `1540` and `1541` are labeled semantically (`close_hand` and `open_hand`) because those are explicitly referenced in the assignment summary table. The remaining codes are kept as `code_1536` ... `code_1542`.

## Verification Performed
- MATLAB static analysis (`checkcode`) passes for `main.m` and all modified helper functions.
- An end-to-end MATLAB runtime test was executed successfully on `S1/R1`.
- That test confirmed:
  - the pipeline runs through EEGLAB, ICA, ICLabel, interpolation, epoching, and trial rejection
  - the extracted epoch length is `4352` samples
  - class `1540` produced `6` trials for the tested run
  - the conservative detector rejected `2` channels on that run

## Remaining Work / Recommended Follow-Up
- Run the full dataset once from `main.m` and inspect the saved outputs for all subjects.
- Compare the automatically detected bad channels and good-trial percentages against the instructor-provided reference lists, if available.
- If runtime becomes a bottleneck, compile the ICLabel dependencies or adjust the EEGLAB installation so ICLabel does not fall back to the slower MATLAB-only path.
- If you have the official semantic names for codes `1536` to `1542`, replace the placeholder labels in `constants.m`.
