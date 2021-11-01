#!/bin/bash
## deepcopy_brain_measures_only.bash -- Copy only requested files from a FreeSurfer dir to another location

APPTAG="[DEEP_CP_BRAIN]"

if [ -z "$3" ]; then
  echo "$APPTAG ERROR: Missing arguments."
  echo "$APPTAG Usage: $0 <source_dir> <dest_dir> [--lfile <lfile> | <src_file>] [<subdir>] [<subjects_file>]"
  echo "$APPTAG    <source_dir>    : path to the source directory containing recon-all output."
  echo "$APPTAG    <dest_dir>      : path to the destination directory. typically empty, must exist."
  echo "$APPTAG    <lfile>         : path to text file containing one source filename per line."
  echo "$APPTAG    <src_file>      : a single source filename. this is only the name, like 'lh.white'. searched for in <subdir>."
  echo "$APPTAG    Note that only one of '--lfile <lfile>' and '<src_file>' can be used (and must be used)."
  echo "$APPTAG    <subdir>        : optional, the subdir under the directory of the subject in which to look for <src_file> or files listed in <lfile>. Defaults to 'surf'."
  echo "$APPTAG    <subjects_file> : optional, path to text file containing one subject ID per line. Default is to auto-detect subject folders in <source_dir>."
  echo "$APPTAG Examples"
  echo "$APPTAG   * Copy the files <subject>/surf/lh.area for all subjects to another dir:"
  echo "$APPTAG     mkdir ~/data/study1_min/"
  echo "$APPTAG     deepcopy_brain_measures_only.bash /media/ext_disk1/study1_full/ ~/data/study1_min/ lh.area"
  echo "$APPTAG   * Copy the files <subject>/stats/lh.aparc.stats for all subjects to another dir:"
  echo "$APPTAG     deepcopy_brain_measures_only.bash /media/ext_disk1/study1_full/ ~/data/study1_min/ lh.aparc.stats stats"
  echo "$APPTAG   * Copy all files listed in filelist.txt for all subjects to another dir (filelist.txt contains 1 file name per line):"
  echo "$APPTAG     echo \"lh.white rh.white lh.thickness rh.thickness\" | tr ' ' '\n' > filelist.txt"
  echo "$APPTAG     deepcopy_brain_measures_only.bash /media/ext_disk1/study1_full/ ~/data/study1_min/ --lfile filelist_surf.txt surf"
  echo "$APPTAG   * Copy all files listed in filelist.txt for subjects listed in subjects file to another dir:"
  echo "$APPTAG     echo \"subject1 subject2\" | tr ' ' '\n' > subjects.txt"
  echo "$APPTAG     deepcopy_brain_measures_only.bash /media/ext_disk1/study1_full/ ~/data/study1_min/ --lfile filelist_surf.txt surf subjects.txt"
  echo "$APPTAG Note: To copy files from different sub directories, just run the command several times with different <subdir> values."
  exit 1
fi

## Settings
IGNORED_SUBJECTS="fsaverage"  # List of subjects to ignore, even if they have the <subdir>. Separate by spaces.

## Start
LISTFILE=""

SOURCE_DIR="$1"
shift
DEST_DIR="$1"
shift
if [ "$1" = "--lfile" ]; then
  shift  # remove the '--file'
  LISTFILE="$1"
  shift
else
  FILES_TO_COPY="$1" # only the 1 file given directly on the command line
  shift
fi

SUBJECT_SUB_DIR="surf"

if [ -n "$1" ]; then
  SUBJECT_SUB_DIR="$1"
  shift
fi

if [ -n "$1" ]; then
  SUBJECTS_FILE="$1"
  shift
  if [ ! -f "${SUBJECTS_FILE}" ]; then
      echo "$APPTAG ERROR: Subjects file '${SUBJECTS_FILE}' does not exist or cannot be read."
      exit 0
  fi
  SUBJECTS_LIST=$(cat "${SUBJECTS_FILE}" | tr '\n' ' ')
  NUM_SUBJECTS_INFILE=$(echo "${SUBJECTS_LIST}" | wc -w | tr -d '[:space:]')
  echo "$APPTAG Using $NUM_SUBJECTS_INFILE subjects from subjects file '$SUBJECTS_FILE'."
  POTENTIAL_SUBJECT_DIRS=${SUBJECTS_LIST};
  IS_FROM_SUBJECTS_LIST="TRUE"
else
  echo "$APPTAG Scanning source directory '${SOURCE_DIR}' for subjects."
  POTENTIAL_SUBJECT_DIRS=${SOURCE_DIR}/*;
  IS_FROM_SUBJECTS_LIST="FALSE"
fi

### Load file list if '--flist' was given
if [ -n "${LISTFILE}" ]; then
  FILES_TO_COPY=$(cat "${LISTFILE}" | tr '\n' ' ')
  FILE_COUNT_PER_SUBJECT=$(echo "$FILES_TO_COPY" | wc -w | tr -d '[:space:]')
  echo "$APPTAG Using list file '${LISTFILE}' containing ${FILE_COUNT_PER_SUBJECT} files per subject. Looking for them in sub dir '${SUBJECT_SUB_DIR}'."
else
  FILE_COUNT_PER_SUBJECT=1
  echo "$APPTAG Copying single file '${FILES_TO_COPY}' for every subject. Looking for it in sub dir '${SUBJECT_SUB_DIR}'."
fi

### Some sanity checks

if [ ! -d "${SOURCE_DIR}" ]; then
  echo "$APPTAG ERROR: Source directory '${SOURCE_DIR}' does not exist. Exiting."
  exit 1
fi

if [ ! -d "${DEST_DIR}" ]; then
  echo "$APPTAG INFO: Destination directory '${DEST_DIR}' does not exist. It will be created."
fi

NUM_FILES_OR_FOLDERS=0
NUM_SUBJECTS=0
NUM_SUBJECTS_IGNORED=0
NUM_FILES_COPIED=0

for POT_SUBJECT_DIR in ${POTENTIAL_SUBJECT_DIRS};
do
  NUM_FILES_OR_FOLDERS=$((NUM_FILES_OR_FOLDERS + 1))
  if [ "$IS_FROM_SUBJECTS_LIST" = "TRUE" ]; then
      # fix path: add prefix. This is ugly, we should refactor this and fix earlier.
      POT_SUBJECT_DIR="${SOURCE_DIR}/${POT_SUBJECT_DIR}"
  fi
  if [ -d  "${POT_SUBJECT_DIR}/${SUBJECT_SUB_DIR}" ]; then
    NUM_SUBJECTS=$((NUM_SUBJECTS + 1))
    SUBJECT_ID=$(basename "${POT_SUBJECT_DIR}")
    IS_IGNORED="NO"
    for IGNORED_SUBJECT in ${IGNORED_SUBJECTS};
    do
      if [ "${SUBJECT_ID}" = "${IGNORED_SUBJECT}" ]; then
        echo "$APPTAG [-] Ignoring subject ${SUBJECT_ID}."
        IS_IGNORED="YES"
      fi
    done
    if [ "${IS_IGNORED}" = "NO" ]; then
      #echo "$APPTAG [+] Handling subject $SUBJECT_ID"
      # check for the file
      for FILE in $FILES_TO_COPY;
      do
        SOURCE_FILE="${POT_SUBJECT_DIR}/${SUBJECT_SUB_DIR}/${FILE}"
        if [ -f "${SOURCE_FILE}" ]; then
          #echo "$APPTAG   - File found for subject $SUBJECT_ID."
          DEST_DIR_SUBJECT="${DEST_DIR}/${SUBJECT_ID}/${SUBJECT_SUB_DIR}"
          #echo "$APPTAG   - Destination dir for file is ${DEST_DIR_SUBJECT}."
          if [ ! -d "${DEST_DIR_SUBJECT}" ]; then
            #echo "$APPTAG   - Creating destination dir ${DEST_DIR_SUBJECT}."
            mkdir -p "${DEST_DIR_SUBJECT}"
          fi
          cp "${SOURCE_FILE}" "${DEST_DIR_SUBJECT}" && NUM_FILES_COPIED=$((NUM_FILES_COPIED + 1))
        else
          echo "$APPTAG   - File '${SOURCE_FILE}' not found for subject $SUBJECT_ID. Cannot copy it."
        fi
      done
    else
      NUM_SUBJECTS_IGNORED=$((NUM_SUBJECTS_IGNORED + 1))
    fi
  else
      if [ "$IS_FROM_SUBJECTS_LIST" = "TRUE" ]; then
          echo "$APPTAG WARNING: Directory of subject $POT_SUBJECT_DIR does not contain the subdir '$SUBJECT_SUB_DIR' and will be skipped."
      fi
  fi
done

NUM_SUBJECTS_HANDLED=$(echo "$NUM_SUBJECTS - $NUM_SUBJECTS_IGNORED" | bc)
NUM_COPIES_EXPECTED=$(echo "$NUM_SUBJECTS_HANDLED * ${FILE_COUNT_PER_SUBJECT}" | bc)

if [ "$IS_FROM_SUBJECTS_LIST" = "TRUE" ]; then
    echo "Used $NUM_SUBJECTS_INFILE subjects from file '$SUBJECTS_FILE', detected $NUM_SUBJECTS subject dirs (difference in missing!). Ignored $NUM_SUBJECTS_IGNORED of them. Successfully copied $NUM_FILES_COPIED of $NUM_COPIES_EXPECTED expected files."
else
    echo "Checked $NUM_FILES_OR_FOLDERS dir entries, detected $NUM_SUBJECTS subject dirs, ignored $NUM_SUBJECTS_IGNORED of them. Successfully copied $NUM_FILES_COPIED of $NUM_COPIES_EXPECTED expected files."
fi
