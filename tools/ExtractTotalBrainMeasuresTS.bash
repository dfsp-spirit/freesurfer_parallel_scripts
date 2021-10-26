#!/bin/bash
#
#  ExtractTotalBrainMeasuresTS.bash -- parse brain measures for all subjects listed in a file from their respective FreeSurfer output and concatinate it into a single file.
#
#  The former tcsh version was created by Christine Ecker on 07/04/2014.
#  Extended by Tim Schäfer on 2018/06/14. Changes:
#    - compute some simple values directly in this script and add them to the output file (see comment below), so you do not have to add stuff for the two hemispheres in Excel anymore
#    - rename expected input file to 'subjects_analysis.txt' to make it independent of the input file for the FreeSurfer pre-processing scripts
#
#  Rewritten for the Bash shell by Tim Schäfer on 2019/03/22
#  Extended the rewritten version, 2019/10/21:
#          * let the user supply subjects dir and file via command line, so editing the script before running it is no longer needed
#          * check whether required files exist before trying to parse data for a subject.
#          * support FreeSurfer 5 version format of aseg.stats by searching for the old names if the new ones are not found (some entries were renamed, see https://www.mail-archive.com/freesurfer@nmr.mgh.harvard.edu/msg64090.html)
#          * add full error checking: if a value cannot be retrieved (by parsing a file or running mris_anatomical_stats), stop the script and give useful error messages
#          * let the user decide whether or not he/she wants the pial surface data (which requires running mris_anatomical_stats and thus makes the script dramatically slower)
#
# Usage of this script:
# 1) Change into the directory containing your FreeSurfer ouput (i.e. the $SUBJECTS_DIR).
# 2) Make sure you have a subjects_file (a simple text file that contains one subject ID per line).
# 3) Call this script from the SUBJECTS_DIR, see below for exact usage. (The script itself can be somewhere else, that does not matter.)
#
# Example usage (assuming your subjects_file is named 'subjects.txt'):
#   cd ~/mystudy
#   wc -l subjects.txt     # print the number of subjects you want, just to be sure the subjects_file is correct
#   chmod +x ~/path/to/ExtractTotalBrainMeasuresTS.bash        # make script executable, only needed once
#   ~/path/to/ExtractTotalBrainMeasuresTS.bash subjects.txt BrainStatsAll.txt no

if [ "$1" = "-h" -o "$1" = "--help" ]; then
    echo ""
    echo "[=== $0 -- Parse brain stats for a group of subjects from FreeSurfer output files ===]"
    echo "USAGE: $0 <subjects_file> <output_file> <include_pial_tag>"
    echo "    <subjects_file>    : path to a text file containing one subject ID per line. Example: 'subjects.txt'"
    echo "    <output_file>      : path to a the output file that will be written Example: 'brainstats.txt'."
    echo "    <include_pial_tag> : Whether to include pial surface data, which requires mris_anatomical_stats to be run and thus takes much longer. Must be 'yes' or 'no'."
    echo ""
    echo "    This script must be run from within the subjects dir."
    echo ""
    echo "    Example usages:"
    echo "                        cd ~/data/mystudy/"
    echo "                        ~/myscripts/ExtractTotalBrainMeasuresTS.bash subjects.txt brainstats_with_pial.txt yes"
    echo "                        ~/myscripts/ExtractTotalBrainMeasuresTS.bash subjects.txt brainstats_without_pial.txt no"
    echo ""
    exit 0
fi

if [ -z "$3" ]; then
    echo "USAGE: $0 <subjects_file> <output_file> <include_pial_tag>"
    echo "Run '$0 --help' for details."
    exit 1
fi

INCLUDE_PIAL="$3"
if [ "$INCLUDE_PIAL" = "yes" -o "$INCLUDE_PIAL" = "no" ]; then
    echo "Include pial set to $INCLUDE_PIAL"
else
    echo "USAGE: $0 <subjects_file> <output_file> <include_pial_tag>"
    echo "Run '$0 --help' for details."
    exit 1
fi


# Whether to abort if required files are missing for a subject. If set to "no", the subject will be listed with NA entries in the results file.
EXIT_ON_MISSING_DATA="no"

SUBJECTS_FILE="$1"
OUTPUT_FILE="$2"

export SUBJECTS_DIR=`pwd`

APPTAG="[EXTRACT_BRAIN_MEASURES]"


TMP_FILE="tmp_brain_stats.txt" # used for appending to in loop below

if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

if [ ! -f "$SUBJECTS_FILE" ]; then
    echo "$APPTAG ERROR: Subjects file '$SUBJECTS_FILE' does not exist (or cannot be read)."
    exit 1
fi

# Deleting the TMP file is important, as otherwise we will append to an existing file with stuff in it!
if [ -f "$TMP_FILE" ]; then
    rm "$TMP_FILE"
fi

# Check for borken line endings (Windows line endings, '\r\n') in subjects.txt file, a very common error.
# This script can cope with these line endings, but we still warn the user because other scripts may choke on them.
NUM_BROKEN_LINE_ENDINGS=$(grep -U $'\015' "${SUBJECTS_FILE}" | wc -l | tr -d '[:space:]')
if [ $NUM_BROKEN_LINE_ENDINGS -gt 0 ]; then
    echo "$APPTAG WARNING: Your subjects file '${SUBJECTS_FILE}' contains $NUM_BROKEN_LINE_ENDINGS incorrect line endings (Windows style line endings)."
    echo "$APPTAG WARNING: (cont.) While this script can work with them, you will run into trouble sooner or later, and you should definitely fix them (use  the 'tr' command or a proper text editor)."
fi

SUBJECTS=$(cat "${SUBJECTS_FILE}" | tr -d '\r' | tr '\n' ' ')    # fix potential windows line endings (delete '\r') and replace newlines by spaces as we want a list
NUM_SUBJECTS=$(cat "$SUBJECTS_FILE" | wc -l | tr -d '[:space:]')



echo "$APPTAG =====Extracting Brain Info====="
echo "$APPTAG Subjects directory: $SUBJECTS_DIR"
echo "$APPTAG Subjects file containing $NUM_SUBJECTS subjects: $SUBJECTS_FILE"
echo "$APPTAG Output file: $OUTPUT_FILE"


# Quickly check for all required files before starting the real work. The reason for doing this in a separate loop is that
# running mris_anatomical_stats takes a long time, and so the script may crash very late if one of the later subjects is missing
# some files if we wait.

### Function to check for missing files. USAGE: subject_has_missing_files <subject> <include_pial>
### IMPORTATNT: For the return value, you have to check the exit status, ?$
subject_has_missing_files () {
      subject=$1
      INCLUDE_PIAL=$2
      NUM_MISSING=0

      ### Adapt paths for EUAIMS, where the subject data is NOT directly in the subject dir. Set to "${subject}/stats" for all standard FreeSurfer data.
      ### Notice: This variable exists again in the next loop, make sure to change it there as well.
      #SUBJECT_STATS_DIR="${subject}/FreeSurfer_v6/Release_2020_02_27/stats"
      SUBJECT_STATS_DIR="${subject}/stats"
      #SUBJECT_LABEL_DIR="${subject}/FreeSurfer_v6/Release_2020_02_27/label"
      SUBJECT_LABEL_DIR="${subject}/label"

      # Check for files.
      for SFILE in "${SUBJECT_STATS_DIR}/lh.aparc.stats" "${SUBJECT_STATS_DIR}/rh.aparc.stats" "${SUBJECT_STATS_DIR}/aseg.stats";
      do
          if [ ! -f "$SFILE" ]; then
              echo "$APPTAG ERROR: Missing file '$SFILE' for subject ${subject}."
              NUM_MISSING=$((NUM_MISSING + 1))
          fi
      done

      if [ "$INCLUDE_PIAL" = "yes" ]; then
          for SFILE in "${SUBJECT_LABEL_DIR}/lh.cortex.label" "${SUBJECT_LABEL_DIR}/rh.cortex.label";
          do
              if [ ! -f "$SFILE" ]; then
                  echo "$APPTAG ERROR: Missing file '$SFILE' for subject ${subject}, required for pial surface stats computation."
                  NUM_MISSING=$((NUM_MISSING + 1))
              fi
          done
      fi
      return $NUM_MISSING
}


NUM_SUBJECTS_MISSING_FILES=0
for subject in $SUBJECTS;
do
    subject_has_missing_files "$subject" "$INCLUDE_PIAL"
    NUM_MISSING_FILES_THIS_SUBJECT=$?
    if [ ${NUM_MISSING_FILES_THIS_SUBJECT} -gt 0 ]; then
        NUM_SUBJECTS_MISSING_FILES=$((NUM_SUBJECTS_MISSING_FILES + 1))
        echo "$APPTAG WARNING: Subject '$subject' is missing $NUM_MISSING_FILES_THIS_SUBJECT required data files."
    fi
done



if [ ${NUM_SUBJECTS_MISSING_FILES} -gt 0 ]; then
    if [ "$EXIT_ON_MISSING_DATA" = "yes" ]; then
        echo "$APPTAG ERROR: $NUM_SUBJECTS_MISSING_FILES subjects are is missing files (see above). Cannot compute brainstats. Exiting (see setting EXIT_ON_MISSING_DATA)."
        exit 1
    else
        echo "$APPTAG WARNING: $NUM_SUBJECTS_MISSING_FILES subjects are is missing files (see above). Their values will be NA in the results."
    fi
fi

CURRENT_SUBJECT_NUM=0
for subject in $SUBJECTS;
do
    subject_has_missing_files "$subject" "$INCLUDE_PIAL"
    NUM_MISSING_FILES_THIS_SUBJECT=$?
    if [ ${NUM_MISSING_FILES_THIS_SUBJECT} -gt 0 ]; then
        if [ "$EXIT_ON_MISSING_DATA" = "yes" ]; then
            echo "$APPTAG ERROR: subject '$subject' is missing files, exiting. This should habve been detected earlier, and the script should have aborted already. Fix this bug!"
            exit 1
        else
            echo "$APPTAG NOTICE: Subject '$subject' is missing required data files, writing NA values to results."
            NAV="NA" # the value to write for NA.
            # write NA values for this subject
            if [ "$INCLUDE_PIAL" = "yes" ]; then
                echo "$subject $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV" >> "$TMP_FILE"
            else
                echo "$subject $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV $NAV" >> "$TMP_FILE"
            fi
            continue
        fi
    fi

    ### Adapt paths for EUAIMS, where the subject data is NOT directly in the subject dir. Set to "${subject}/stats" for all standard FreeSurfer data.
    ### Notice: This variable exists again in the previous loop, make sure to change it there as well.
    #SUBJECT_STATS_DIR="${subject}/FreeSurfer_v6/Release_2020_02_27/stats"
    SUBJECT_STATS_DIR="${subject}/stats"
    #SUBJECT_LABEL_DIR="${subject}/FreeSurfer_v6/Release_2020_02_27/label"
    SUBJECT_LABEL_DIR="${subject}/label"

    CURRENT_SUBJECT_NUM=$((CURRENT_SUBJECT_NUM + 1))
    echo "$APPTAG +++++ Starting to work on subject '$subject' ($CURRENT_SUBJECT_NUM of $NUM_SUBJECTS). +++++"

    lhCortexVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep lhCortexVol | awk -F'[, \t]*' '{print $11}'`
    echo "$APPTAG lhCortexVol: $lhCortexVol"
    rhCortexVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep rhCortexVol | awk -F'[, \t]*' '{print $11}'`
    echo "$APPTAG rhCortexVol: $rhCortexVol"
    CortexVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep 'Total cortical gray matter volume' | awk -F'[, \t]*' '{print $10}'`
    echo "$APPTAG CortexVol: $CortexVol"
    if [ -z "$CortexVol" ]; then
        echo "ERROR: Could not determine CortexVol (subject='${$subject}')."
        exit 1
    fi

    CerebralWhiteMatterVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep 'Total cerebral white matter volume' | awk -F'[, \t]*' '{print $10}'`

    if [ -z "$CerebralWhiteMatterVol" ]; then
        # aseg file from FreeSurfer 5, most likely.
        CerebralWhiteMatterVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep 'Total cortical white matter volume' | awk -F'[, \t]*' '{print $10}'`
        if [ -z "$CerebralWhiteMatterVol" ]; then
            echo "ERROR: Could not determine white matter volume from ${SUBJECT_STATS_DIR}/aseg.stats (subject='${$subject}')"
            exit 1
        fi
    fi

    echo "$APPTAG CerebralWhiteMatter: $CerebralWhiteMatterVol"

    TotalGray=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep TotalGray | awk -F'[, \t]*' '{print $9}'`
    echo "$APPTAG TotalGray: $TotalGray"
    SubCortGray=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep SubCortGray | awk -F'[, \t]*' '{print $9}'`
    echo "$APPTAG SubCortGray: $SubCortGray"

    EstimatedTotalIntraCranialVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep EstimatedTotalIntraCranialVol | awk -F'[, \t]*' '{print $9}'`
    if [ -z "$EstimatedTotalIntraCranialVol" ]; then
        # aseg file from FreeSurfer 5, most likely.
        EstimatedTotalIntraCranialVol=`more ${SUBJECT_STATS_DIR}/aseg.stats | grep 'IntraCranialVol' | awk -F'[, \t]*' '{print $7}'`
        if [ -z "$EstimatedTotalIntraCranialVol" ]; then
            echo "ERROR: Could not determine total IntraCranial volume from ${SUBJECT_STATS_DIR}/aseg.stats (subject='${$subject}')"
            exit 1
        fi
    fi

    echo "$APPTAG EstimatedTotalIntraCranialVol: $EstimatedTotalIntraCranialVol"

    #using *h.aparc.stats
    lhMeanThickness=`more ${SUBJECT_STATS_DIR}/lh.aparc.stats | grep MeanThickness | awk -F'[, \t]*' '{print $7}'`
    echo "$APPTAG lhMeanThickness: $lhMeanThickness"
    rhMeanThickness=`more ${SUBJECT_STATS_DIR}/rh.aparc.stats | grep MeanThickness | awk -F'[, \t]*' '{print $7}'`
    echo "$APPTAG rhMeanThickness: $rhMeanThickness"

    #computed by: mris_anatomical_stats -l lh.cortex.label $subject lh white
    lhWhiteSurfArea=`more ${SUBJECT_STATS_DIR}/lh.aparc.stats | grep WhiteSurfArea | awk -F'[, \t]*' '{print $9}'`
    echo "$APPTAG lhWhiteSurfArea: $lhWhiteSurfArea"
    rhWhiteSurfArea=`more ${SUBJECT_STATS_DIR}/rh.aparc.stats | grep WhiteSurfArea | awk -F'[, \t]*' '{print $9}'`
    echo "$APPTAG rhWhiteSurfArea: $rhWhiteSurfArea"

    if [ "$INCLUDE_PIAL" = "yes" ]; then
        # pial area is not computed by default, we need to run mris_anatomical_stats ourselves and parse the output to get it.
        lhPialSurfArea=`mris_anatomical_stats -l lh.cortex.label $subject lh pial | grep 'total surface area' | awk '{print $5}'`
        if [ -z "$lhPialSurfArea" ]; then
            echo "ERROR: Could not determine lh pial surface area of subject $subject by running mris_anatomical_stats. Please check for mris_anatomical_stats errors (subject='${$subject}')."
            exit 1
        fi
        echo "lhPialSurfArea: $lhPialSurfArea"
        rhPialSurfArea=`mris_anatomical_stats -l rh.cortex.label $subject rh pial | grep 'total surface area' | awk '{print $5}'`
        if [ -z "$rhPialSurfArea" ]; then
            echo "ERROR: Could not determine rh pial surface area of subject $subject by running mris_anatomical_stats. Please check for mris_anatomical_stats errors. (subject='${$subject}')."
            exit 1
        fi
        echo "$APPTAG rhPialSurfArea: $rhPialSurfArea"

        # Added by Tim: Directly perform some simple computations here and save the values to the stats file (no need to do that in Excel)
        totalPialSurfArea=`echo "$lhPialSurfArea + $rhPialSurfArea" | bc -l`
        echo "$APPTAG totalPialSurfArea: $totalPialSurfArea"
        if [ -z "$totalPialSurfArea" ]; then
            echo "ERROR: Could not determine totalPialSurfArea, computed from lhPialSurfArea = '${lhPialSurfArea}' and rhPialSurfArea = '${rhPialSurfArea}' (subject='${$subject}')."
            exit 1
        fi
    fi

    totalWhiteSurfArea=`echo "$lhWhiteSurfArea + $rhWhiteSurfArea" | bc -l`
    echo "$APPTAG totalWhiteSurfArea: $totalWhiteSurfArea"
    if [ -z "$totalWhiteSurfArea" ]; then
        echo "ERROR: Could not determine totalWhiteSurfArea, computed from lhWhiteSurfArea = '${lhWhiteSurfArea}' and rhWhiteSurfArea = '${rhWhiteSurfArea}' (subject='${$subject}')."
        exit 1
    fi
    totalMeanCorticalThickness=`echo "scale=5;($lhMeanThickness + $rhMeanThickness) / 2" | bc -l`
    echo "$APPTAG totalMeanCorticalThickness: $totalMeanCorticalThickness"
    if [ -z "$totalMeanCorticalThickness" ]; then
        echo "ERROR: Could not determine totalMeanCorticalThickness, computed from lhMeanThickness = '${lhMeanThickness}' and rhMeanThickness = '${rhMeanThickness}' (subject='${$subject}')."
        exit 1
    fi
    totalBrainVolume=`echo "$CerebralWhiteMatterVol + $TotalGray" | bc -l`
    echo "$APPTAG CerebralWhiteMatterVol: $CerebralWhiteMatterVol TotalGray: $TotalGray"
    echo "$APPTAG totalBrainVolume: $totalBrainVolume"
    if [ -z "$totalBrainVolume" ]; then
        echo "ERROR: Could not determine totalBrainVolume, computed from CerebralWhiteMatterVol = '${CerebralWhiteMatterVol}' and TotalGray = '${TotalGray}' (subject='${$subject}')."
        exit 1
    fi

    if [ "$INCLUDE_PIAL" = "yes" ]; then
        echo "$subject $CortexVol $CerebralWhiteMatterVol $TotalGray $EstimatedTotalIntraCranialVol $lhMeanThickness $rhMeanThickness $lhWhiteSurfArea $rhWhiteSurfArea $lhPialSurfArea $rhPialSurfArea $totalPialSurfArea $totalWhiteSurfArea $totalMeanCorticalThickness $totalBrainVolume" >> "$TMP_FILE"
    else
        echo "$subject $CortexVol $CerebralWhiteMatterVol $TotalGray $EstimatedTotalIntraCranialVol $lhMeanThickness $rhMeanThickness $lhWhiteSurfArea $rhWhiteSurfArea $totalWhiteSurfArea $totalMeanCorticalThickness $totalBrainVolume" >> "$TMP_FILE"
    fi
done

if [ "$INCLUDE_PIAL" = "yes" ]; then
    echo "subject CortexVol CerebralWhiteMatterVol TotalGray EstimatedTotalIntraCranialVol lhMeanThickness rhMeanThickness lhWhiteSurfArea rhWhiteSurfArea lhPialSurfArea rhPialSurfArea totalPialSurfArea totalWhiteSurfArea totalMeanCorticalThickness totalBrainVolume" > BrainStats.hdr
else
    echo "subject CortexVol CerebralWhiteMatterVol TotalGray EstimatedTotalIntraCranialVol lhMeanThickness rhMeanThickness lhWhiteSurfArea rhWhiteSurfArea totalWhiteSurfArea totalMeanCorticalThickness totalBrainVolume" > BrainStats.hdr
fi
cat BrainStats.hdr "$TMP_FILE" >> "$OUTPUT_FILE"
rm "$TMP_FILE" BrainStats.hdr

echo "$APPTAG Results for the $NUM_SUBJECTS subjects are in '$OUTPUT_FILE'."

if [ ${NUM_SUBJECTS_MISSING_FILES} -gt 0 ]; then
    echo "$APPTAG WARNING: $NUM_SUBJECTS_MISSING_FILES subject(s) were is missing required data files (see above). Their values are NA in the results."
fi
