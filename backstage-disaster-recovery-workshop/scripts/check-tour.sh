#!/usr/bin/env bash
# Maintainer check, not part of the lab: validates the rendered tour.
# Valid JSON; every file step's file, line and selection exist (steps without a file are content steps); every '>>' command is a Makefile target;
# every link resolves (workspace files exist, command links are known, web links are the portal).
source "$(dirname "$0")/lib.sh"
cd "${ROOT_DIR}"

"${ROOT_DIR}/scripts/render-tour.sh"
TOUR=".tours/backstage-dr.tour"
errors=0
err() { printf '\033[31m✘\033[0m %s\n' "$*"; errors=$(( errors + 1 )); }

jq empty "${TOUR}" || fail "${TOUR} is not valid JSON"
grep -q '{{' "${TOUR}" && err "unrendered placeholder left in ${TOUR}"
[[ "$(jq -r .title "${TOUR}")" == "#1 - "* ]] || err "title must start with '#1 - ' to be the primary tour"

targets="$(grep -oE '^[a-z0-9-]+:' Makefile | tr -d :)"
url="$(base_url)"
count="$(jq '.steps | length' "${TOUR}")"
for i in $(seq 0 $(( count - 1 ))); do
  step="$(jq -c ".steps[${i}]" "${TOUR}")"
  n=$(( i + 1 ))
  file="$(jq -r '.file // empty' <<<"${step}")"
  line="$(jq -r '.line // empty' <<<"${step}")"
  desc="$(jq -r '.description' <<<"${step}")"

  sel_start="$(jq -r '.selection.start.line // empty' <<<"${step}")"
  sel_end="$(jq -r '.selection.end.line // empty' <<<"${step}")"

  # A step without a file is a content step: CodeTour shows it on a page of its own.
  if [[ -z "${file}" ]]; then
    [[ -z "${line}${sel_start}" ]] || err "step ${n}: a line or selection needs a file"
  elif [[ -z "${line}" ]]; then
    err "step ${n}: a file step needs a line"
  elif [[ ! -f "${file}" ]]; then
    err "step ${n}: file ${file} does not exist"
  else
    lines="$(wc -l <"${file}")"
    (( line >= 1 && line <= lines )) || err "step ${n}: ${file} has no line ${line}"
    if [[ -n "${sel_start}${sel_end}" ]]; then
      if [[ -z "${sel_start}" || -z "${sel_end}" ]]; then
        err "step ${n}: selection needs a start and an end"
      elif (( sel_start < 1 || sel_end > lines || sel_start > sel_end )); then
        err "step ${n}: selection ${sel_start}-${sel_end} is not inside ${file} (1-${lines})"
      fi
    fi
  fi

  while read -r cmd; do
    [[ -z "${cmd}" ]] && continue
    target="${cmd#make }"
    if [[ "${cmd}" != "make ${target}" ]] || ! grep -qx "${target}" <<<"${targets}"; then
      err "step ${n}: '>> ${cmd}' is not a Makefile target"
    fi
  done < <(grep -E '^>> ' <<<"${desc}" | sed 's/^>> //')

  while read -r link; do
    [[ -z "${link}" ]] && continue
    case "${link}" in
      command:simpleBrowser.show\?*)
        arg="$(perl -MURI::Escape -e 'print uri_unescape($ARGV[0])' "${link#*\?}" 2>/dev/null \
          || python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "${link#*\?}")"
        [[ "$(jq -r '.[0]' <<<"${arg}")" == "${url}" ]] || err "step ${n}: Simple Browser link does not open ${url}" ;;
      command:*) err "step ${n}: unknown command link ${link}" ;;
      http*) [[ "${link}" == "${url}"* ]] || err "step ${n}: web link ${link} is not the portal" ;;
      ./*) [[ -e "${link}" ]] || err "step ${n}: link ${link} does not exist" ;;
      *) err "step ${n}: link ${link} is neither a workspace file nor the portal" ;;
    esac
  done < <(grep -oE '\]\([^)]+\)' <<<"${desc}" | sed -E 's/^\]\(//; s/\)$//')

  if [[ -z "${file}" ]]; then
    ok "step ${n}: $(jq -r .title <<<"${step}") (content step)"
  else
    ok "step ${n}: $(jq -r .title <<<"${step}") (${file}:${line}${sel_start:+, highlights ${sel_start}-${sel_end}})"
  fi
done

(( errors == 0 )) || fail "${errors} problem(s) in the tour"
ok "Tour is valid: ${count} steps"
