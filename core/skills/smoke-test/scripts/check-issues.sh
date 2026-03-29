  #!/bin/bash                                                                                                                                                                                  
  # check-issues.sh — [D] Check which FAIL results have existing GitHub issues
  # Usage: ./check-issues.sh < results.json                                                                                                                                                    
  # Outputs: JSON array with tracked/untracked status per failure
  set -euo pipefail                                                                                                                                                                            
                                                            
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"                                                                                                                                                  
  # shellcheck source=/dev/null                             
  source "${SCRIPT_DIR}/_smoke-lib.sh"
                                                                                                                                                                                               
  _st_load_config
  _st_require_gh                                                                                                                                                                               
                                                            
  REPO=$(_st_repo)
  LABEL=$(_st_label)

  INPUT=$(cat)                                                                                                                                                                                 
  
  # Extract failures from results JSON                                                                                                                                                         
  FAILURES=$(echo "$INPUT" | jq -c '.results[] | select(.status == "FAIL")')
                                                                                                                                                                                               
  if [[ -z "$FAILURES" ]]; then
      echo "[]"                                                                                                                                                                                
      exit 0                                                
  fi

  echo "["                                                                                                                                                                                     
  FIRST=true
  while IFS= read -r failure; do                                                                                                                                                               
      NAME=$(echo "$failure" | jq -r '.name')               
      URL_PATH=$(echo "$failure" | jq -r '.url')
      ERRORS=$(echo "$failure" | jq -c '.errors // []')                                                                                                                                        
                                                                                                                                                                                               
      # Search for existing open issue                                                                                                                                                         
      EXISTING=$(gh issue list --repo "$REPO" --label "bug,$LABEL" --state open --search "$NAME" --json number,title --jq '.[0].number // empty' 2>/dev/null || echo "")                       
                                                                                                                                                                                               
      $FIRST || echo ","
      FIRST=false                                                                                                                                                                              
                                                                                                                                                                                               
      if [[ -n "$EXISTING" ]]; then
          echo "  {\"name\":$(echo "$NAME" | jq -R .),\"url\":$(echo "$URL_PATH" | jq -R .),\"errors\":${ERRORS},\"tracked\":true,\"issue_number\":${EXISTING}}"                               
      else                                                                                                                                                                                     
          echo "  {\"name\":$(echo "$NAME" | jq -R .),\"url\":$(echo "$URL_PATH" | jq -R .),\"errors\":${ERRORS},\"tracked\":false,\"issue_number\":null}"
      fi                                                                                                                                                                                       
  done <<< "$FAILURES"                                      
  echo "]"
