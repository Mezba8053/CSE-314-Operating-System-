#!/bin/bash

VERBOSE=0
NO_EXECUTE=0
NO_LINE_COUNT=0
NO_COMMENT_COUNT=0
NO_FUNCTION_COUNT=0
for argument in "$@"; do
    case $argument in
    -v) VERBOSE=1 ;;
    -noexecute) NO_EXECUTE=1 ;;
    -nolc) NO_LINE_COUNT=1 ;;
    -nocc) NO_COMMENT_COUNT=1 ;;
    -nofc) NO_FUNCTION_COUNT=1 ;;
    esac
done
if [ $# -lt 4 ]; then
    echo "Error: Insufficient arguments"
    echo "Usage: $0 <submissions_dir> <target_dir> <tests_dir> <answers_dir> [options]"
    exit 1
fi

# Process mandatory arguments
SUBMISSIONS_DIR="$1"
TARGET_DIR="$2"
TESTS_DIR="$3"
ANSWERS_DIR="$4"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR/"
# echo "Script Directory: $SCRIPT_DIR"

TESTS_DIR="$WORKSPACE_DIR/tests"
ANSWERS_DIR="$WORKSPACE_DIR/answers"
# Validate submissions directory
if [ ! -d "$SUBMISSIONS_DIR" ]; then
    echo "Error: Submissions directory $SUBMISSIONS_DIR does not exist"
    exit 1
fi

# Validate or create target directory
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR/$TARGET_DIR" || {
        echo "Error: Failed to create target directory $TARGET_DIR"
        exit 1
    }
fi

# Validate tests directory
if [ ! -d "$TESTS_DIR" ]; then
    echo "Error: Tests directory $TESTS_DIR does not exist"
    exit 1
fi

# Validate answers directory
if [ ! -d "$ANSWERS_DIR" ]; then
    echo "Error: Answers directory $ANSWERS_DIR does not exist"
    exit 1
fi

cd "$SUBMISSIONS_DIR" || {
    echo "Error: Failed to change to submissions directory $SUBMISSIONS_DIR"
    exit 1
}

for zip in *.zip; do
    if [ -f "$zip" ]; then
        folder="${zip%.zip}"
        if [ ! -d "$folder" ]; then
            unzip -o "$zip" -d "$folder" >/dev/null
            # else
            # echo " Folder $folder already exists, skipping."
        fi
    else
        echo " No zip files found in $SUBMISSIONS_DIR"
    fi
done

# Arrays to hold found files
files_c=()
files_cpp=()
files_java=()
files_py=()
declare -a name_c
declare -a name_cpp
declare -a name_java
declare -a name_py

# Loop through unzipped folders
for folder in */; do
    for inner in "$folder"/*; do
        if [ -d "$inner" ]; then
            cd "$inner" || continue

            if find . -type f -name "*.c" | grep -q .; then
                found_c=$(find . -type f -name "*.c" | head -n 1)
                files_c+=("$(realpath "$found_c")")
                # echo " Found C file: $found_c"

                # Extract student name and roll number from the path
                student_details=$(basename "$inner")
                # echo "student_details: $student_details" student_name=$(echo "$student_details" | awk -F'_' '{print $1}')
                student_name=$(echo "$student_details" | awk -F'_' '{print $1}')

                roll_no=$(echo "$student_details" | awk -F'_' '{print $4}')
                name_c[$roll_no]="$student_name"
                # echo " Student cccccc Name: $student_name, Roll Number: $roll_no"
            elif find . -type f -name "*.cpp" | grep -q .; then
                found_cpp=$(find . -type f -name "*.cpp" | head -n 1)
                # echo " Found C++   vff file: $found_cpp"
                files_cpp+=("$(realpath "$found_cpp")")
                # echo " Found C++ file: $found_cpp"
                # Extract student name and roll number from the path
                # student_details=$(basename "$(dirname "$(dirname "$found_cpp")")")

                student_details=$(basename "$inner")
                # echo "student_details: $student_details"
                student_name=$(echo "$student_details" | awk -F'_' '{print $1}')
                roll_no=$(echo "$student_details" | awk -F'_' '{print $4}')
                name_cpp[$roll_no]="$student_name"
                # roll_no=$(basename "$inner" | awk -F'_' '{print $4}')
            elif find . -type f -name "*.java" | grep -q .; then
                found_java=$(find . -type f -name "*.java" | head -n 1)
                files_java+=("$(realpath "$found_java")")
                # echo " Found Java file: $found_java"
                # Extract student name and roll number from the path
                student_details=$(basename "$inner")
                # echo "student_details: $student_details"
                student_name=$(echo "$student_details" | awk -F'_' '{print $1}')
                roll_no=$(echo "$student_details" | awk -F'_' '{print $4}')
                name_java[$roll_no]="$student_name"
                # echo " Student Name: $student_name, Roll Number: $roll_no"
            elif find . -type f -name "*.py" | grep -q .; then
                found_py=$(find . -type f -name "*.py" | head -n 1)
                files_py+=("$(realpath "$found_py")")
                # echo " Found Python file: $found_py"
                # Extract student name and roll number from the path
                student_details=$(basename "$inner")
                # echo "student_details: $student_details"
                student_name=$(echo "$student_details" | awk -F'_' '{print $1}')
                roll_no=$(echo "$student_details" | awk -F'_' '{print $4}')
                name_py[$roll_no]="$student_name"
                # echo " Student Name: $student_name, Roll Number: $roll_no"
            else
                echo " No supported files in $inner"
            fi

            cd - >/dev/null || exit 1
        fi
    done
done
# echo "Found Cpp files: ${name_cpp[@]}"
# echo "Found xssC files: ${found_c[@]}"
# }
declare -A total_c
declare -A total_cpp
declare -A total_python
declare -A total_java
analyze_file() {
    file_path="$1"
    roll_no="$2"

    # Total lines
    # echo "Analyzing file: $file_path"
    total_lines=$(wc -l <"$file_path")

    # Comment lines: handle only single-line comments (// for C/C++ and # for Python)
    if [[ "$file_path" == *.c ]] || [[ "$file_path" == *.cpp ]]; then
        comment_lines=$(grep -Eoc '//|/\*|\*/' "$file_path")
    elif [[ "$file_path" == *.java ]]; then
        comment_lines=$(grep -Eoc '//|/\*|\*/' "$file_path")
    elif [[ "$file_path" == *.py ]]; then
        comment_lines=$(grep -Eoc '#' "$file_path")
    else
        comment_lines=0
    fi
    # Count the number of functions in the file
    if [[ "$file_path" == *.c ]] || [[ "$file_path" == *.cpp ]]; then
        function_count=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([^;]*\)[[:space:]]*\{' "$file_path" | wc -l)
    elif [[ "$file_path" == *.java ]]; then
        function_count=$(grep -E '^[[:space:]]*((public|private|protected|static|final|native|synchronized|abstract|strictfp)[[:space:]]+)*[[:alnum:]_<>]+[[:space:]]+[[:alnum:]_]+[[:space:]]*\([^)]*\)' "$file_path" | wc -l)
    elif [[ "$file_path" == *.py ]]; then
        function_count=$(awk '/^[[:space:]]*def[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(/' "$file_path" | wc -l)
    else
        function_count=0
    fi

    # Output format
    echo "$roll_no $comment_lines $total_lines $function_count"
}

# mkdir -p ./targets/{c,cpp,java,python}

for file in "${files_c[@]}"; do
    roll_no=$(echo "$file" | grep -oE '[0-9]{7,}' | tail -n 1)
    student_details_c=$(basename "$(dirname "$file")")
    # echo "name: $student_details_c"

    mkdir -p "../targets/c/$roll_no"
    # echo " Copying C file to ./targets/c/$roll_no/main.c"
    cp "$file" "../targets/c/$roll_no/main.c"
    echo "Organizing files of $roll_no"

    total_c["$roll_no"]=$(analyze_file "../targets/c/$roll_no/main.c" "$roll_no")
    # echo "total_c: ${total_c[@]}"

done

for file in "${files_cpp[@]}"; do
    if [ -f "$file" ]; then
        # echo "file: $file"
        roll_no=$(basename "$(dirname "$(dirname "$(dirname "$file")")")" | awk -F'_' '{print $4}')

        if [ -z "$roll_no" ]; then
            echo "Error: Could not extract roll number for file $file. Skipping."
            continue
        fi

        # echo "roll_no: $roll_no"
        student_details_cpp=$(basename "$(dirname "$file")")
        # echo "name: $student_details_cpp"
        mkdir -p "../targets/c++/$roll_no"
        cp "$file" "../targets/c++/$roll_no/main.cpp"
        echo "Organizing files of $roll_no"

        # echo "Copied C++ file to ./targets/cpp/$roll_no/main.cpp"
        total_cpp["$roll_no"]=$(analyze_file "../targets/c++/$roll_no/main.cpp" "$roll_no")
        # echo "total_cpp: ${total_cpp[@]}"
    else
        echo "Skipping invalid file or directory: $file"
    fi
done

for file in "${files_java[@]}"; do
    roll_no=$(echo "$file" | grep -oE '[0-9]{7,}' | tail -n 1)
    student_details_java=$(basename "$(dirname "$file")")
    # echo "name: $student_details_java"
    mkdir -p "../targets/java/$roll_no"
    cp "$file" "../targets/java/$roll_no/Main.java"
    echo "Organizing files of $roll_no"
    # echo " Copied Java file to ./targets/java/$roll_no/Main.java"
    total_java["$roll_no"]=$(analyze_file "../targets/java/$roll_no/Main.java" "$roll_no")
    # echo "total_java: ${total_java[@]}"
done

for file in "${files_py[@]}"; do
    roll_no=$(echo "$file" | grep -oE '[0-9]{7,}' | tail -n 1)
    student_details_py=$(basename "$(dirname "$file")")
    # echo "name: $student_details_py"
    mkdir -p "../targets/python/$roll_no"
    cp "$file" "../targets/python/$roll_no/main.py"
    echo "Organizing files of $roll_no"
    # echo " Copied Python file to ./targets/python/$roll_no/main.py"
    total_python["$roll_no"]=$(analyze_file "../targets/python/$roll_no/main.py" "$roll_no")
    # echo "total_python: ${total_python[@]}"
done

mapfile -t input_files < <(find "$TESTS_DIR" -type f | sort 2>/dev/null)
mapfile -t answer_files < <(find "$ANSWERS_DIR" -type f | sort 2>/dev/null)
if [ $NO_EXECUTE -eq 0 ] && [ $VERBOSE -eq 1 ]; then
    files_execution=()
    declare -A output_total
    declare -A output_match_c
    declare -A output_match_cpp
    declare -A output_match_java
    declare -A output_match_py

    for dir in ../targets/c/*; do
        if [ -d "$dir" ]; then
            cd "$dir" || continue
            if gcc -o main.out main.c; then
                chmod +x main.out
                roll_no=$(basename "$dir")
                echo "Executing files of roll $roll_no"

                for i in "${!input_files[@]}"; do
                    input_file="${input_files[$i]}"
                    answer_file="${answer_files[$i]}"
                    test_name=$(basename "$input_file")

                    val=$(echo "$test_name" | grep -oE '[0-9]+' | head -n 1)
                    output_file="out${val}.txt"

                    if ./main.out <"$input_file" >"$output_file"; then
                        output_total["$roll_no"]=$((output_total["$roll_no"] + 1))
                        if diff -q "$output_file" "$answer_file" >/dev/null; then
                            output_match_c["$roll_no"]=$((output_match_c["$roll_no"] + 1))
                        fi
                    else
                        rm -f "$output_file"
                    fi
                done
            else
                echo "Compilation failed in $dir."
            fi
            cd - >/dev/null || exit 1
        fi
    done

    for dir in ../targets/c++/*; do
        if [ -d "$dir" ]; then
            cd "$dir" || continue
            if g++ -o main.out main.cpp; then
                chmod +x main.out
                roll_no=$(basename "$dir")
                echo "Executing files of roll $roll_no"

                for i in "${!input_files[@]}"; do
                    input_file="${input_files[$i]}"
                    answer_file="${answer_files[$i]}"
                    test_name=$(basename "$input_file")

                    val=$(echo "$test_name" | grep -oE '[0-9]+' | head -n 1)
                    output_file="out${val}.txt"

                    if ./main.out <"$input_file" >"$output_file"; then
                        output_total["$roll_no"]=$((output_total["$roll_no"] + 1))
                        if diff -q "$output_file" "$answer_file" >/dev/null; then
                            output_match_cpp["$roll_no"]=$((output_match_cpp["$roll_no"] + 1))
                        fi
                    else
                        rm -f "$output_file"
                    fi
                done
            else
                echo "Compilation failed in $dir."
            fi
            cd - >/dev/null || exit 1
        fi
    done

    for dir in ../targets/java/*; do
        if [ -d "$dir" ]; then
            cd "$dir" || continue
            if javac Main.java; then
                chmod +x Main.class
                roll_no=$(basename "$dir")
                echo "Executing files of roll $roll_no"

                for i in "${!input_files[@]}"; do
                    input_file="${input_files[$i]}"
                    answer_file="${answer_files[$i]}"
                    test_name=$(basename "$input_file")

                    val=$(echo "$test_name" | grep -oE '[0-9]+' | head -n 1)
                    output_file="out${val}.txt"

                    if java Main <"$input_file" >"$output_file"; then
                        output_total["$roll_no"]=$((output_total["$roll_no"] + 1))
                        if diff -q "$output_file" "$answer_file" >/dev/null; then
                            output_match_java["$roll_no"]=$((output_match_java["$roll_no"] + 1))
                        fi
                    else
                        rm -f "$output_file"
                    fi
                done
            else
                echo "Compilation failed in $dir."
            fi
            cd - >/dev/null || exit 1
        fi
    done

    for dir in ../targets/python/*; do
        if [ -d "$dir" ]; then
            cd "$dir" || continue
            roll_no=$(basename "$dir")
            chmod +x main.py
            echo "Executing files of roll $roll_no"

            for i in "${!input_files[@]}"; do
                input_file="${input_files[$i]}"
                answer_file="${answer_files[$i]}"
                test_name=$(basename "$input_file")

                val=$(echo "$test_name" | grep -oE '[0-9]+' | head -n 1)
                output_file="out${val}.txt"

                if python3 main.py <"$input_file" >"$output_file"; then
                    output_total["$roll_no"]=$((output_total["$roll_no"] + 1))
                    if diff -q "$output_file" "$answer_file" >/dev/null; then
                        output_match_py["$roll_no"]=$((output_match_py["$roll_no"] + 1))
                    fi
                else
                    rm -f "$output_file"
                fi
            done
            cd - >/dev/null || exit 1
        fi
    done
    echo "All submissions processed successfully."
fi

# for roll_no in "${!output_match_c[@]}"; do
# echo "sss"

# echo "name: ${name_c[@]}"
# echo "details : ${total_c[@]}"
# echo "Oumitput match C: ${output_total[@]}"
temp_csv_body="$WORKSPACE_DIR/$TARGET_DIR/temp_result.csv"
result_csv="$WORKSPACE_DIR/$TARGET_DIR/result.csv"
declare -A processed_rolls

# Generate the CSV header dynamically based on flags
header="student_id,student_name,language"
[ $NO_EXECUTE -eq 0 ] && header+=",matched,not_matched"
[ $NO_LINE_COUNT -eq 0 ] && header+=",line_count"
[ $NO_COMMENT_COUNT -eq 0 ] && header+=",comment_count"
[ $NO_FUNCTION_COUNT -eq 0 ] && header+=",function_count"

echo "$header" >"$result_csv"
# cat "$header"
{
    for file in "${files_c[@]}"; do
        roll_no=$(echo "$file" | grep -oE '[0-9]{7,}' | tail -n 1)
        if [[ -n "$roll_no" && -z "${processed_rolls[$roll_no]}" ]]; then
            processed_rolls["$roll_no"]=1
            student_name="${name_c[$roll_no]}"
            com_count=$(echo "${total_c[$roll_no]}" | awk '{print $2}')
            total_lines=$(echo "${total_c[$roll_no]}" | awk '{print $3}')
            function_count=$(echo "${total_c[$roll_no]}" | awk '{print $4}')

            output="$roll_no,$student_name,C"
            if [ $NO_EXECUTE -eq 0 ]; then
                matched=${output_match_c[$roll_no]:-0}
                non_matched=$((output_total["$roll_no"] - matched))
                output+=",$matched,$non_matched"
            fi
            [ $NO_LINE_COUNT -eq 0 ] && output+=",$total_lines"
            [ $NO_COMMENT_COUNT -eq 0 ] && output+=",$com_count"
            [ $NO_FUNCTION_COUNT -eq 0 ] && output+=",$function_count"

            echo "$output"
        fi
    done

    for dir in ../targets/c++/*; do
        roll_no=$(basename "$dir")
        if [[ -n "$roll_no" && -z "${processed_rolls[$roll_no]}" ]]; then
            processed_rolls["$roll_no"]=1
            student_name="${name_cpp[$roll_no]}"
            com_count=$(echo "${total_cpp[$roll_no]}" | awk '{print $2}')
            total_lines=$(echo "${total_cpp[$roll_no]}" | awk '{print $3}')
            function_count=$(echo "${total_cpp[$roll_no]}" | awk '{print $4}')

            output="$roll_no,$student_name,C++"
            if [ $NO_EXECUTE -eq 0 ]; then
                matched=${output_match_cpp[$roll_no]:-0}
                non_matched=$((output_total["$roll_no"] - matched))
                output+=",$matched,$non_matched"
            fi
            [ $NO_LINE_COUNT -eq 0 ] && output+=",$total_lines"
            [ $NO_COMMENT_COUNT -eq 0 ] && output+=",$com_count"
            [ $NO_FUNCTION_COUNT -eq 0 ] && output+=",$function_count"

            echo "$output"
        fi
    done

    for file in "${files_java[@]}"; do
        roll_no=$(echo "$file" | grep -oE '[0-9]{7,}' | tail -n 1)
        if [[ -n "$roll_no" && -z "${processed_rolls[$roll_no]}" ]]; then
            processed_rolls["$roll_no"]=1
            student_name="${name_java[$roll_no]}"
            com_count=$(echo "${total_java[$roll_no]}" | awk '{print $2}')
            total_lines=$(echo "${total_java[$roll_no]}" | awk '{print $3}')
            function_count=$(echo "${total_java[$roll_no]}" | awk '{print $4}')

            output="$roll_no,$student_name,Java"
            if [ $NO_EXECUTE -eq 0 ]; then
                matched=${output_match_java[$roll_no]:-0}
                non_matched=$((output_total["$roll_no"] - matched))
                output+=",$matched,$non_matched"
            fi
            [ $NO_LINE_COUNT -eq 0 ] && output+=",$total_lines"
            [ $NO_COMMENT_COUNT -eq 0 ] && output+=",$com_count"
            [ $NO_FUNCTION_COUNT -eq 0 ] && output+=",$function_count"

            echo "$output"
        fi
    done

    for file in "${files_py[@]}"; do
        roll_no=$(echo "$file" | grep -oE '[0-9]{7,}' | tail -n 1)
        if [[ -n "$roll_no" && -z "${processed_rolls[$roll_no]}" ]]; then
            processed_rolls["$roll_no"]=1
            student_name="${name_py[$roll_no]}"
            com_count=$(echo "${total_python[$roll_no]}" | awk '{print $2}')
            total_lines=$(echo "${total_python[$roll_no]}" | awk '{print $3}')
            function_count=$(echo "${total_python[$roll_no]}" | awk '{print $4}')

            output="$roll_no,$student_name,Python"
            if [ $NO_EXECUTE -eq 0 ]; then
                matched=${output_match_py[$roll_no]:-0}
                non_matched=$((output_total["$roll_no"] - matched))
                output+=",$matched,$non_matched"
            fi
            [ $NO_LINE_COUNT -eq 0 ] && output+=",$total_lines"
            [ $NO_COMMENT_COUNT -eq 0 ] && output+=",$com_count"
            [ $NO_FUNCTION_COUNT -eq 0 ] && output+=",$function_count"

            echo "$output"
        fi
    done
} >"$temp_csv_body"

sort -t, -k2,2 "$temp_csv_body" >>"$result_csv"
rm -f "$temp_csv_body"
echo "CSV file generated at $TARGET_DIR/result.csv"
