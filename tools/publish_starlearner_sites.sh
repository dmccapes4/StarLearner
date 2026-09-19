#!/usr/bin/env bash
# Publish Star Learner public portal + dylanmccapes.systems Star Learner section.
# Requires host sudo (run in your Terminal — agents do not escalate on this machine).
#
#   bash /home/dylanmccapes/dev/star_learning/tools/publish_starlearner_sites.sh
#
set -euo pipefail

echo "▸ starlearner.dylanmccapes.systems (site/ → /var/www/starlearner)"
sudo bash /home/dylanmccapes/dev/star_learning/deploy/deploy.sh

echo ""
echo "▸ dylanmccapes.systems (index + media)"
sudo bash /home/dylanmccapes/dev/dylanmccapes-systems/deploy.sh

echo ""
echo "Verify:"
echo "  curl -sI https://starlearner.dylanmccapes.systems/ | head -5"
echo "  curl -sI https://starlearner.dylanmccapes.systems/games/ant/ | head -5"
echo "  curl -sI https://dylanmccapes.systems/ | head -5"
