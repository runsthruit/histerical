#! /dev/null/bash

function ___tmp () {

    shopt -u cmdhist
    shopt -s histappend
    shopt -u lithist

    HISTFILE="${XDG_DATA_HOME}/bash/_history.d/${HOSTNAME}/${USER}/$( date "+%Y-%m-%d/%H-%M-%S" ).$$.bash_history"

    mkdir -p "${HISTFILE%/*}"

}
___tmp 1>&2
unset -f ___tmp

function history ()
{

    declare HISTTIMEFORMAT="${HISTTIMEFORMAT}"

    [ -t 1 ] \
        || declare HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S %z%t"

    builtin history "${@}"

}

function hist ()
{ hists 1 "${@}"; }

function hists ()
{

    declare vars=(
        fnc
        days
        grep_args
    )
    declare ${vars[*]}

    fnc="${FUNCNAME[0]}"

    [[ "${#}" -gt 0 && "${1}" =~ ^[0-9]+$ ]] || {
        printf \
                "${fnc}: %s\n" \
                "Why: List/Grep shell history." \
                "Use: ${fnc} ___days___ [___grep_arg___ ...]"
        return 1
    } 1>&2

    days="${1}"
    shift
    grep_args=( "${@:-.}" )

    find \
            "${XDG_DATA_HOME}/bash/_history.d/." \
            -name "*.bash_history" \
            -type f \
            -mtime "-${days}" \
            -print0 |
        xargs -0 grep -l "${grep_args[@]}" |
        while read H
        do
            {
                grep -En '^#[0-9]{10,}$'   "${H}" |
                    cut -d: -f1 |
                    sed 's/$/:0/'
                grep -n  "${grep_args[@]}" "${H}" |
                    cut -d: -f1 |
                    sed 's/$/:1/'
            } |
                sort -t: -k 1,1g -k 2,2g |
                sort -t: -k 1,1g -u |
                grep -B1 :1$ |
                grep -A1 :0$ |
                sed -n 's/:[01]$/p/p' |
                paste -d";" - - - - - - - - - - - - - - - - - - - - |
                xargs -I@ sed -n '@' "${H}" |
                paste - -
        done |
            sort -u |
            sort -k 1,1g

}

function hist_pull ()
{

    history -a

    declare HISTCONTROL='ignorespace'"${HISTCONTROL:+:${HISTCONTROL}}"
    declare HISTIGNORE=' *'"${HISTIGNORE:+:${HISTIGNORE}}"
    declare HISTTIMEFORMAT='%Y-%m-%d %H:%M:%S %z%t'
    declare histchars="${histchars:-!^#}"

    declare vars=(
        tc_tab
        tmpf
    )
    declare ${vars[*]}

    printf -v tc_tab '\t'

    tmpf="${TMPDIR:-/tmp}/hist_pull.$$.${RANDOM:-${SECONDS:-_}}.cleaned"

    history -c

    {
        printf "%s %s HIST_PULL\n" 0 $(( $( date -j "+%s" ) - ( ${1:-1} * 24 * 60 * 60 ) ))
        find "${HISTFILE%/*/*/*}/." -mindepth 3 -maxdepth 3 \! -a -type d -a -mtime -${1:-1} -name "*.bash_history" -print |
        tee >( grep -c . | sed "s/.*/${FUNCNAME[0]}: Loading [ & ] Files/" 1>&2 ) |
        tr "\n" "\0" |
        xargs -0 cat |
        tr "\t" "\0" |
        awk '/^#[0-9]{9,}$/{if(NR!=1){printf("\n")};sub(/^#/,"");printf("%s %s",NR,$0);next};{printf("\t%s",$0)}' |
        sed "s/${tc_tab}/ /" |
        grep -v "${tc_tab}" |
        uniq -f2
    } |
        sort -k 2,2g -k 1,1g |
        uniq -f1 |
        sed -n "/^0 [0-9][0-9]* HIST_PULL\$/,\$p" |
        sed "1d;s/^[0-9]* \([0-9]*\) /#\1${tc_tab}/" |
        tee >( grep -c "^#" | sed "s/.*/${FUNCNAME[0]}: Loading [ & ] Entries/" 1>&2 ) |
        tr "\t" "\n" |
        tr "\0" "\t" \
        > "${tmpf}"

    history -r "${tmpf}"

    rm -f "${tmpf}"

}
