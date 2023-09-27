#!/usr/bin/env bash

# nd_array - n-dimensional nested array managemnt for bash

nd_usage() {
    ## displays a quick usage example for how to use the nd_array functions
    
cat<<'EOF'

## nd_array usage example
# Example to create a 2 x 3 x 4 x 5 array with increasing integer values. The array basename is 'A'. 
# Actual data values will be saved in arrays names A_W_X_Y[Z], where W={0,1}; X={0,1,2}; Y={0,1,2,3}; Z={0,1,2,3,4};
    
# # # # #  generate nameref framework. 
# note: dont include the last dimension

source <(nd_create -a A 2 3 4)
   
# # # # # set array values
# pass data to be set on STDIN, and use function inputs to define basename + index ranges

source <(seq 1 $(( 2 * 3 * 4 * 5 )) | nd_set A 0:1 0:2 0:3 0:4)
    
# # # # # read array slices
# get various slices of the array. pass ranges as quoted space-seperated list of as start:end or [start:end]. '@' and '*' give all indicies in that dimension.
# NOTE: THE VALUES RETURNED WILL ALWAYS HAVE THE LAST DIMENSION ON A SINGLE LINE, AND LINE ORDERING BASED ON THE OTHER DIMENSIONS. 
# this may or may not match expected array ordering, as in the output all but the last dimension are collapsed into a single dimension 
# (i.e., a N x M x P (3D) array becomes (N*M) x P (2D) in the output. where {N=0,M=*,P=*} is shown first, then {N=1,M=*,P=*}, etc.

nd_get A 0 '1 2' '*' 0:3
nd_get A '1' '@' '@' [0:2]

# # # # # clear array and nameref framework variables

nd_clear A

EOF

}
 
nd_create() {
    # generates a series of narerefs and arrays to traverse a N-dimensional nested array structure
    # first input is basename, remaining inputs are dimension sizes
    # set 1st input (before basename) to `-a` or `--auto` to allow for single number inputs (e.g., `5`) to be automatically expanded to e.g., `[0:5]`
    #
    # NOTE: do not include indicies for the final dimension of the array you want to create. These will be saved as array elements
    #        in the last nameref'd array, and as such dont need individual nameref's created for them
    #
    # NOTE: ${1,,} ${1,,}_[0-9] ${1,,}_[0-9]_[0-9] ... will be used for the dummy nameref variables (lowercase)
    # NOTE: ${1^^} ${1^^}_[0-9] ${1^^}_[0-9]_[0-9] ... will be used for the mapping arrays that hold these dummy nameref variables (UPPERCASE)
    #
    # NOTE: this provides code that needs to be sourced in the calling shell. Run this as `source <(nd_create [-a] <BASENAME> <INDICIES>)`
    
    local echoStr_A echoStr_a autoFlag nn
    local -a inAll dec_new
    local -l -a deca_new deca_old
    local -u -a decA_new decA_old
    local -i jj kk nDim
    
    if [[ "${1,,}" =~ ^-+a(uto)?$ ]]; then
        autoFlag=true
        shift 1
    else
        autoFlag=false
    fi
    
    [[ "$1" =~ ^[A-Za-z].*$ ]] || { printf '\nERROR: THE GIVEN "BASE-NAME" (%s) MUST BEGIN WITH  CHARACTER TO BE A VALID VARIABLE NAME> EXITING' "$1" >&2; return 1; }
    
    inAll=("$@")
    
    [[ ${#} == 1 ]] && return
    
    echoStr_A="${1^^}"    
    echoStr_a="${1,,}"    
    kk=2
    nDim=0
    while (( ${kk} <= ${#} )); do
        if ${autoFlag} || ! [[ "${!kk}" =~ ^[0-9]*[1-9]+[0-9]*$ ]]; then 
            echoStr_A+="$({ source /proc/self/fd/0; }<<<"printf '%s ' $({ [[ "${!kk}" =~ ^[0-9]*[1-9]+[0-9]*$ ]] && echo '0:'"$(( ${!kk^^} - 1 ))" || echo "${!kk^^}"; } | sed -E s/'^\[?([0-9]+)\:([0-9])+\]?$'/'{\1..\2}'/)" | sed -E 's/[[:space:]]*$//;s/ /,/g;s/^(.+)$/_{\1}/')"
            echoStr_a+="$({ source /proc/self/fd/0; }<<<"printf '%s ' $({ [[ "${!kk}" =~ ^[0-9]*[1-9]+[0-9]*$ ]] && echo '0:'"$(( ${!kk,,} - 1 ))" || echo "${!kk,,}"; } | sed -E s/'^\[?([0-9]+)\:([0-9])+\]?$'/'{\1..\2}'/)" | sed -E 's/[[:space:]]*$//;s/ /,/g;s/^(.+)$/_{\1}/')"
        else
            echoStr_A+="_${!kk^^}"
            echoStr_a+="_${!kk,,}"
        fi
        ((kk++))
        ((nDim++))
    done
    echoStr_A+=$'\n'
    echoStr_a+=$'\n'
    mapfile -t decA_new < <({ source /proc/self/fd/0 | tr ' '  $'\n'; }<<<"echo ${echoStr_A}")
    mapfile -t deca_new < <({ source /proc/self/fd/0 | tr ' '  $'\n'; }<<<"echo ${echoStr_a}")
    
    until (( ${nDim} == 0 )); do

        printf '\n' 
        echo "declare -a ${decA_new[@]}"
        printf '\n'
        for kk in "${!decA_new[@]}"; do
            printf 'declare -n %s=%s\n' "${deca_new[$kk]}"  "${decA_new[$kk]}" 
        done
    

        decA_old=("${decA_new[@]}")
        
        mapfile -t decA_new < <(printf '%s\n' "${decA_old[@]%_*}" | sort -u)
        printf '%s\n' "${dec_new[@]}"
        
        for nn in "${decA_new[@]}"; do
cat<<EOF
mapfile -t ${nn} < <(printf '%s\\n' $(printf '%q ' "${deca_new[@]}") | grep -F "${nn,,}" | sort -u)
EOF
        done

        deca_old=("${deca_new[@]}")

        mapfile -t deca_new < <(printf '%s\n' "${deca_old[@]%_*}" | sort -u)

        ((nDim--))
    done
}

nd_clear() {
    # clears set arraysand namerefs. 
    # acceptsb 1 input: basename
    # all variables of the following forms will be unset: '${1^^}' '${1,,}' '${1^^}_[0-9]' '${1,,}_[0-9]' '${1^^}_[0-9]_..._[0-9]' '${1,,}_[0-9]_..._[0-9]'

    local varList
    
    [[ "$1" =~ ^[A-Za-z].*$ ]] || { printf '\nERROR: THE GIVEN "BASE-NAME" (%s) MUST BEGIN WITH  CHARACTER TO BE A VALID VARIABLE NAME> EXITING' "$1" >&2; return 1; }

    varList="$(declare -p | grep -iE 'declare (-. )?'"$1"'(_[0-9]+)*' | sed -E 's/^declare (-.)? //; s/=.+$//')"
    source <(echo "${varList}" | grep -E "^${1,,}" | sed -E s/'^'/'declare +n '/)
    unset ${varList}
}

nd_set() {
    ## assigns values to nd_array. 
    # first inout is basename, remaining inputs are ranges of indeicies for each dimension. 
    # pass data to assign on stdin. each index is assigned 1 line. any remaining data will be saved in array dataExtra
    #
    # NOTE: this provides code that needs to be sourced in the calling shell. Run this as `source <(printf '%s\n' "${vals[@]}" | nd_ set <BASENAME> <INDICIES>)`

    
    local AA echoStr_A 
    local -i kk jj
    local -a indToAssign
    
    [[ "$1" =~ ^[A-Za-z].*$ ]] || { printf '\nERROR: THE GIVEN "BASE-NAME" (%s) MUST BEGIN WITH  CHARACTER TO BE A VALID VARIABLE NAME> EXITING' "$1" >&2; return 1; }

    echoStr_A="$1"
    kk=2
    while (( ${kk} < ${#} )); do
        if [[ "${!kk}" =~ ^[0-9]*[1-9]+[0-9]*$ ]]; then 
            echoStr_A+="_${!kk^^}"
        else
            echoStr_A+="$({ source /proc/self/fd/0; }<<<"printf '%s ' $(echo "${!kk^^}" | sed -E s/'^\[?([0-9]+)\:([0-9])+\]?$'/'{\1..\2}'/)" | sed -E 's/[[:space:]]*$//;s/ /,/g;s/^(.+)$/_{\1}/')"
        fi
        ((kk++))
    done
    if [[ "${!kk}" =~ ^[0-9]*[1-9]+[0-9]*$ ]]; then 
        echoStr_A+="[${!kk}"]
    else
        echoStr_A+="$({ source /proc/self/fd/0; }<<<"printf '%s ' $(echo "${!kk^^}" | sed -E s/'^\[?([0-9]+)\:([0-9])+\]?$'/'{\1..\2}'/)" | sed -E 's/[[:space:]]*$//;s/ /,/g;s/^(.+)$/\[{\1}\]/')"
    fi
    echoStr_A+=$'\n'
    mapfile -t indToAssign < <({ source /proc/self/fd/0 | tr ' '  $'\n'; }<<<"echo ${echoStr_A}")
        
    jj=0
    { while true; do
        if (( $jj >= ${#indToAssign[@]} )); then
            if read -r -t 1 -N 1 -u ${fd0}; then
                    mapfile -t dataExtra -u ${fd0}} {fd0}<&0
                dataExtra[0]="${REPLY}${dataExtra[0]}"
                printf '\n%s\n' 'WARNING: there were more lines given on STDIN than there were indicies in the specified ranges.'$'\n''Extra lines from STDIN have been saved in array "dataExrta"' >&2
            fi    
            break
                
        elif read -r -t 1 -u ${fd0}; then
            printf '%s="%s"\n' "${indToAssign[$jj]}" "${REPLY}"
            ((jj++))
            
        else
            printf '\n%s\n' 'WARNING: More indicies were specified than the number of lines given on STDIN. Part of the specified index ranges are not set.' >&2
            break
        fi
    done; } {fd0}<&0
    
    echo ${A_1_2_3[4]}
         
}



nd_get() {
    ## 
    # 1st input is array basename, remaining inputs are indicies (or ranges of indicies)
    # this will work its way through the indicies 1 at a time, and for each it uses
    #  a dummy nameref to get the array that leads to the next index then recursively
    # calls itself again with 1 less input, until there are only 2 inputs left
    #
    # DEFINING RANGES OF INDICIES -- this can be done via
    # ---> a (quoted) space seperated list: '0 1 3 5'
    # ---> an array-like syntax range: '0:3' --OR-- '[0:3]'
    # ---> use '@' or '*' to get all values in that array dimension
    # 
    # NOTE: the above methods cannot be combined. e.g., '0 1 3:5` will NOT work
    #
    # NOTE: arrays may have inconsistent dimensionality. By default, if part of a range
    #       does not exist this will print a blank line for every missing end point.
    # FLAG: set '-q' or '--quiet' as the 1st input to avoid printing these "placeholder" blank lines 
    # NOTE: THE VALUES RETURNED WILL ALWAYS HAVE THE LAST DIMENSION ON A SINGLE LINE, AND LINE ORDERING BASED ON THE OTHER DIMENSIONS. 
    # this may not match typical array ordering, as in the output all but the last dimension are collapsed into a single dimension (i.e., a N x M x P (3D) array becomes (N*M) x P (2D) in the output.

    local valCur valNew AA kk jj quietFlag haveOutFlag
    
    case "$1" in
        -q|--quiet)
            quietFlag=true
            shift 1
        ;;
        *)
            quietFlag=false
        ;;
    esac
    
    [[ "$1" =~ ^[A-Za-z].*$ ]] || { printf '\nERROR: THE GIVEN "BASE-NAME" (%s) MUST BEGIN WITH  CHARACTER TO BE A VALID VARIABLE NAME> EXITING' "$1" >&2; return 1; }
    
    shopt -s extglob
   
    case ${#} in
        1)  
            return 
        ;;
        2)  
            declare -n AA="$1"
            haveOutFlag=false
            if [[ "${2}" == [@\*] ]]; then
                 [[ ${AA[*]} ]] && printf '%s\t' "${AA[@]}" && haveOutFlag=true
            else
                for jj in $({ source /proc/self/fd/0; }<<<"printf '%s ' $(echo "${2}" | sed -E s/'^\[?([0-9]+)\:([0-9])+\]?$'/'{\1..\2}'/)"); do
                    [[ ${AA[${jj}]} ]] && printf '%s\t' "${AA[${jj}]}" && haveOutFlag=true
                done
            fi
            if ${haveOutFlag}; then
                printf '\n'
            else
                ${quietFlag} || printf '\n'
            fi
        ;;
        *)                  
            declare -n AA="$1"
            for jj in $([[ "${2}" == [@\*] ]] && echo ${!AA[@]} || { source /proc/self/fd/0; }<<<"printf '%s ' $(echo "${2}" | sed -E s/'^\[?([0-9]+)\:([0-9])+\]?$'/'{\1..\2}'/)"); do
                if [[ -z ${AA[$jj]} ]]; then
                    continue
                elif ${quietFlag}; then
                    nd_get -q "${AA[$jj]}" "${@:3}"
                else
                    nd_get "${AA[$jj]}" "${@:3}"
                fi
            done
        ;;
    esac
        
    declare +n AA
}
