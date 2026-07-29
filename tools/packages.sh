#!/usr/bin/env bash
# Canonical Android package IDs for Star Learner (source once in deploy/build scripts).
PKG_LAUNCHER=com.dylan.star_learner
PKG_ANT_EXPLORER=com.dylan.ant_explorer
PKG_GARDEN_EXPLORER=com.dylan.antexplorer.garden
PKG_SOLAR_EXPLORER=com.dylan.solar_system_explorer
PKG_MATH_EXPLORER=com.dylan.math_explorer
PKG_LANGUAGE_EXPLORER=com.dylan.language_explorer
EXTRA_WIPE_SAVE=com.dylan.star_learner.EXTRA_WIPE_SAVE

# Ordered arrays for full_deploy (launcher first, then games).
PACKAGES=(
  "$PKG_LAUNCHER"
  "$PKG_ANT_EXPLORER"
  "$PKG_GARDEN_EXPLORER"
  "$PKG_SOLAR_EXPLORER"
  "$PKG_MATH_EXPLORER"
  "$PKG_LANGUAGE_EXPLORER"
)
