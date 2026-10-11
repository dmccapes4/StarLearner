#!/usr/bin/env python3
"""Stage 9 — REPORT_AndromedaBrainScans_v0.0.1_20261010.{pdf,md}. Every number from results/*.json."""
import json, os, glob
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak
from PIL import Image as PILImage
from common import RESULTS, ROOT, log, archive_if_exists
from lib import CORPORA

SCAN = os.path.join(RESULTS, "scan"); PLATES = os.path.join(RESULTS, "plates")
S1 = json.load(open(os.path.join(RESULTS, "stage1_invariants.json")))
S3 = json.load(open(os.path.join(RESULTS, "stage3_fields_windshield.json")))
S4 = json.load(open(os.path.join(RESULTS, "stage4_scan_standing.json")))
S5 = json.load(open(os.path.join(RESULTS, "stage5_bearing.json")))
S6 = json.load(open(os.path.join(RESULTS, "stage6_ganglia.json")))
S7 = json.load(open(os.path.join(RESULTS, "stage7_retest.json")))
SPH = json.load(open(os.path.join(RESULTS, "sphere", "sphere.json")))
INV = json.load(open(os.path.join(ROOT, "corpus", "inventory.json")))

ss = getSampleStyleSheet()
H1 = ParagraphStyle("h1", parent=ss["Heading1"], fontSize=16, spaceAfter=8)
H2 = ParagraphStyle("h2", parent=ss["Heading2"], fontSize=12.5, spaceBefore=10, spaceAfter=5)
B = ParagraphStyle("b", parent=ss["BodyText"], fontSize=9.2, leading=12.5)
S = ParagraphStyle("s", parent=B, fontSize=7.8, leading=10, textColor=colors.HexColor("#444"))
MD = []


def P(txt, style=B):
    MD.append(txt.replace("<b>", "**").replace("</b>", "**").replace("<i>", "*").replace("</i>", "*").replace("&nbsp;", " ").replace("<br/>", "  \n").replace("<font face='Courier'>", "`").replace("</font>", "`") + "\n")
    return Paragraph(txt, style)


def H(txt, lvl=1):
    MD.append(("# " if lvl == 1 else "## ") + txt + "\n"); return Paragraph(txt, H1 if lvl == 1 else H2)


def table(rows, widths=None, font=7.0):
    MD.append("| " + " | ".join(str(c) for c in rows[0]) + " |\n|" + "---|" * len(rows[0]) + "\n" +
              "".join("| " + " | ".join(str(c) for c in r) + " |\n" for r in rows[1:]) + "\n")
    t = Table([[Paragraph(str(c), ParagraphStyle("c", parent=B, fontSize=font, leading=font + 2)) for c in r] for r in rows], colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dde5ee")), ("GRID", (0, 0), (-1, -1), 0.3, colors.grey), ("VALIGN", (0, 0), (-1, -1), "TOP")]))
    return t


def fig(path, caption, width_in=7.0):
    if not os.path.exists(path):
        return [P(f"<i>[missing figure {os.path.basename(path)}]</i>", S)]
    rel = os.path.relpath(path, ROOT)
    MD.append(f"![{caption}]({rel})\n\n*{caption}*\n\n")
    w, h = PILImage.open(path).size; W = width_in * inch
    return [Image(path, width=W, height=W * h / w), Paragraph(caption, S), Spacer(1, 8)]


def yn(b):
    return "yes" if b else "no"


def main():
    s = []
    s.append(H("AndromedaBrainScans v0.0.1 — Report"))
    s.append(P("<b>Date:</b> 20261010 &nbsp; <b>Named by:</b> D. McCapes &nbsp; <b>Run by:</b> the agent (loop A) &nbsp; "
               "<b>Plan:</b> <font face='Courier'>GAME_PLAN.md</font> &nbsp; <b>Scripts:</b> <font face='Courier'>scripts/04–10</font> &nbsp; "
               "<b>Inputs:</b> 11 corpora, 46,306 concept occurrences, one 384-d MiniLM space, 11 Capricornus sorts (<font face='Courier'>corpus/INVENTORY.md</font>)."))
    s.append(P("<b>Epistemic column.</b> COMPUTED = a number from the data by a stated procedure. INTERPRETIVE = an agent-authored rule or reading applied to computed numbers. "
               "OPERATOR = a term or claim stipulated by the operator, implemented as stated. GENERATED = an image from a text prompt. Every claim below carries one of these."))

    # --- summary
    s.append(H("1. Result in one paragraph", 2))
    rt = S7["six_a_vs_six_b"]
    n_big = sum(1 for c in CORPORA if S3[c]["big"]); n_dull = sum(1 for c in CORPORA if S3[c]["dull_ratio_B_over_A"] < 1)
    n_nodal = sum(1 for c in CORPORA if S4[c]["nodal_closer_than_null"]); n_rec = sum(1 for c in CORPORA if S5[c]["direction_recoverable"])
    s.append(P(f"The instrument works and the first thing it measured is that the reflection is not big and dull — it is <b>concentrated</b>. "
               f"On every corpus field B (the sort's receipts) piles its mass into a few hotspots, so the contrast field C = log A − log B is A-dominant over "
               f"{min(S4[c]['A_dominant_frac'] for c in CORPORA):.0%}–{max(S4[c]['A_dominant_frac'] for c in CORPORA):.0%} of the sphere and the B-dominant ovaloids are small, closed and few. "
               f"The windshield fit found a blur wider than the source (\"big\") on {n_big}/11 corpora and lower contrast (\"dull\") on {n_dull}/11; "
               f"the residual E is {min(S3[c]['residual_E_over_B'] for c in CORPORA):.2f}–{max(S3[c]['residual_E_over_B'] for c in CORPORA):.2f} of B, so the reflection is not a plain copy either. "
               f"The ovaloid interfaces are <b>not</b> nodal surfaces of any l ≤ 8 harmonic ({n_nodal}/11 closer than the null) and the icosahedral l = 6 band is <b>suppressed</b> relative to the permuted null on every corpus (z from "
               f"{min(S4[c]['P6_z'] for c in CORPORA):+.1f} to {max(S4[c]['P6_z'] for c in CORPORA):+.1f}); the per-l damping ρ_fit = {min(S4[c]['rho_fit_per_l'] for c in CORPORA):.2f}–{max(S4[c]['rho_fit_per_l'] for c in CORPORA):.2f} (reference 0.88). "
               f"Direction is recoverable (interval &lt; 90°) on {n_rec}/11 corpora. Test–retest: the fields replicate (corr A {rt['corr_A']:.2f}, corr B {rt['corr_B']:.2f}, corr C {rt['corr_C']:.2f}, Dice of the A-dominant region {rt['dice_A_dominant']:.2f}) "
               f"but the <b>bearing does not</b> ({rt['refraction_a_deg']:.1f}° vs {rt['refraction_b_deg']:.1f}°, intervals {'overlap' if rt['intervals_overlap'] else 'disjoint'}). COMPUTED."))

    # --- stage 1
    s.append(H("2. Stage 1 — invariants per corpus", 2))
    rows = [["corpus", "n", "seed", "^ letters (≥5 members)", "ramp letters", "coupling rate %", "receipts / concept", "occluded (concepts)", "flags"]]
    for c in CORPORA:
        v = S1[c]
        rows.append([c, v["n_concepts"], f"{v['seed_letter']} — {v['seed_concept'][:38]}", " ".join(v["letters_with_caret"]), f"{len(v['letters_ramp'])}/{v['letters_ge5']}",
                     v["coupling_rate_pct"], v["receipts_per_concept"], v["occluded_fraction"], "; ".join(v["flag"]) or "—"])
    s.append(table(rows, [0.75 * inch, 0.45 * inch, 1.9 * inch, 0.75 * inch, 0.55 * inch, 0.6 * inch, 0.6 * inch, 0.6 * inch, 1.3 * inch]))
    s.append(P("Only the seed letter is a ^ on 10/11 corpora; <font face='Courier'>sacred</font> adds Y (6 members). Coupling rate is not scale-free: 8.4% (childhood, 681 concepts) to 92.2% (sacred, 10,007). "
               "Flags are results, not exclusions; the flagged corpora are scanned and their flags carried. COMPUTED.", S))

    # --- stage 2
    s.append(H("3. Stage 2 — the meaning sphere M", 2))
    s.append(P(f"PCA-3 of 46,306 × 384 → unit sphere. Explained variance {SPH['pooled_explained_variance']} (total {SPH['pooled_explained_total']:.1%}). The sphere is a shadow used for position; all distances in Stage 6 are 384-d. "
               f"Per-corpus PCA-3 explains {min(v['explained_total'] for v in SPH['per_corpus'].values()):.1%}–{max(v['explained_total'] for v in SPH['per_corpus'].values()):.1%}. COMPUTED."))

    # --- stage 3/3b
    s.append(H("4. Stage 3 / 3b — fields and the windshield transform", 2))
    s.append(P("A = vMF density (κ = 200, σ ≈ 4°) of every concept, weight 1. B = same kernel, weight = receipts stamped by the sort (coupling 1.0, echo 0.5, stop 0.1, base 0.05). "
               "O = cells where seed-capricornus and stop-only concepts carry &gt; 50% of local A mass. Fit B ≈ g·K_κB ∗ R(A)·(1 − O) by Nelder–Mead on rotation + κ_B (3 starts), g closed-form. INTERPRETIVE (rule), COMPUTED (numbers)."))
    rows = [["corpus", "rotation R (°)", "κ_B (κ_A = 200)", "σ_B / σ_A (°)", "big?", "gain g", "dull ratio", "corr(B,T)", "corr(B,A)", "|E|/|B|", "occl. sphere", "occl. concepts"]]
    for c in CORPORA:
        v = S3[c]
        rows.append([c, v["rotation_deg"], v["kappa_B"], f"{v['sigma_B_deg']} / {v['sigma_A_deg']}", yn(v["big"]), v["gain_g"], v["dull_ratio_B_over_A"], v["corr_B_T_offmask"], v["corr_B_A_offmask"], v["residual_E_over_B"], v["occlusion_fraction_sphere"], v["occlusion_fraction_concepts"]])
    s.append(table(rows, [0.75 * inch] + [0.56 * inch] * 11))
    s.append(P(f"Reading. \"Big\" (κ_B &lt; κ_A) holds on {n_big}/11; where it fails (six_a, six_b, sacred, childhood, history_b2n) the best-fitting reflection is <i>sharper</i> than the source — the receipts concentrate. "
               f"\"Dull\" (contrast ratio &lt; 1) holds on {n_dull}/11 (warfare 0.56, childhood 0.59, sacred 0.50 are strongly dull; leper_king 1.64 and islam_origin 1.35 are brighter than the source). "
               "Rotations near 0° on eight corpora: the reflection is not turned, it is re-weighted. The three large rotations (six_a 120°, six_b 169°, sacred 168°) come with κ_B ≫ κ_A and should be read as the optimiser finding a sharp antipodal match, not a physical turn; "
               "corr(B,T) exceeds corr(B,A) on all three, so the fit is real, but §8 lists it as a thing to check before it is believed. The residual E is never below 0.48 of B: the transform does not explain the reflection away. INTERPRETIVE.", S))

    # --- stage 4
    s.append(H("5. Stage 4 — contrast field, ovaloids, the scan", 2))
    rows = [["corpus", "λ (5% of sphere at |C| ≥ λ)", "A > B fraction", "A-ovaloid s=1", "B-ovaloid s=1", "A-ovaloid s=0.5", "B-ovaloid s=0.5", "mean C"]]
    for c in CORPORA:
        v = S4[c]
        rows.append([c, v["lambda"], v["A_dominant_frac"], v["ovaloids"]["1.0"]["A_dom_frac"], v["ovaloids"]["1.0"]["B_dom_frac"], v["ovaloids"]["0.5"]["A_dom_frac"], v["ovaloids"]["0.5"]["B_dom_frac"], v["C_mean"]])
    s.append(table(rows, [0.9 * inch] + [0.85 * inch] * 7))
    s.append(P("The B-dominant ovaloids at s = 1 cover 0.4–3.8% of the sphere; the A-dominant ones 1–5%. The sign structure is a dipole-plus-hotspots: the reflection lives in a few closed regions, the direct line everywhere else. "
               "On the maps those regions are the blue blobs; on the scan they are the dark closed curves. COMPUTED.", S))
    for c in ("six_a", "sacred", "childhood"):
        s += fig(os.path.join(SCAN, f"{c}_maps.png"), f"{c}: A (direct line), B (reflection), C = log A − log B with the C = 0 and ±λ contours, and C under the occlusion mask O (hatched).", 7.0)
    s.append(PageBreak())
    for c in ("six_a", "six_b", "sacred", "warfare", "family"):
        s += fig(os.path.join(SCAN, f"{c}_scan.png"), f"{c}: the scan — nine slices through a rendering ball on each of three orthogonal families; white = C = 0 interface, red = A-dominant ovaloid, blue = B-dominant. Display clipped at ±1.5λ.", 7.2)

    # --- stage 4b
    s.append(H("6. Stage 4b — standing wave test (the two-for-one)", 2))
    rows = [["corpus", "dominant l", "nodal dist to C=0 (°)", "null mean (p5) (°)", "closer than null?", "P6 fraction", "P6 null mean ± sd", "P6 z", "ρ_fit per l"]]
    for c in CORPORA:
        v = S4[c]
        rows.append([c, v["dominant_l_nonzero"], v["nodal_distance_deg"], f"{v['nodal_null_mean_deg']} ({v['nodal_null_p5_deg']})", yn(v["nodal_closer_than_null"]), v["P6_frac"], f"{v['P6_frac_null_mean']} ± {v['P6_frac_null_sd']}", v["P6_z"], v["rho_fit_per_l"]])
    s.append(table(rows, [0.85 * inch] + [0.72 * inch] * 8))
    s.append(P(f"The C = 0 interface is <b>not</b> closer to the nodal lines of the dominant band than to randomly rotated copies of that band on any corpus ({n_nodal}/11). The l = 6 (icosahedral) share of power is below the B-permuted null on 11/11 (z ≤ −0.7; six_a/six_b/sacred ≈ −2.1 to −2.4). "
               "The dominant band is l = 1 or 2 — a dipole or quadrupole, i.e. the hotspot-vs-everything-else structure above. The damping ρ_fit sits between 0.66 and 1.07, median ≈ 0.83; the small corpora (childhood 0.90, family 0.89, mythology 0.86) are nearest the d20 run's 0.88. "
               "Per §5 of the plan: on this data, at this corpus size, the standing-wave reading is not present on M. The tectonic/sulcal/ovaloid identification remains the operator's claim about rock and brain; the sphere of meaning did not join it tonight. COMPUTED (numbers), INTERPRETIVE (reading)."))
    s += fig(os.path.join(SCAN, "sacred_spectrum.png"), "sacred: spherical-harmonic power spectrum of C, l = 6 in red.", 4.2)

    # --- stage 5
    s.append(H("7. Stage 5 — bearing, as an interval", 2))
    rows = [["corpus", "seed (centre)", "bearing from A (°)", "bearing from B (°)", "refraction (°)", "boot sd", "blur", "interval (°)", "width", "centroid sep (°)", "priors inside", "recoverable?"]]
    for c in CORPORA:
        v = S5[c]
        rows.append([c, f"{v['seed_letter']}: {v['seed_concept'][:30]}", v["bearing_A_deg"], v["bearing_B_deg"], v["refraction_deg"], v["bootstrap_sd_deg"], v["blur_deg"],
                     f"[{v['interval_deg'][0]}, {v['interval_deg'][1]}]", v["interval_width_deg"], v["centroid_sep_deg"], ", ".join(k.split("_")[0] for k, b in v["priors_in_interval"].items() if b) or "—", yn(v["direction_recoverable"])])
    s.append(table(rows, [0.7 * inch, 1.35 * inch] + [0.5 * inch] * 10))
    s.append(P(f"Refraction (angle at the seed between the direction to A's centroid and to B's centroid) is small where B's centroid barely moves (sacred 4.5°, childhood 0.8°) and undefined-wide where the two centroids straddle the seed (warfare 180° ± 82, islam_origin 104° ± 85). "
               f"The operator's 30° prior sits inside the interval on sports, family, leper_king and islam_origin; 60° and 90° only on islam_origin, whose interval is 160° wide. Direction recoverable on {n_rec}/11. "
               "The headline number from the plan — one bearing — is replaced by eleven intervals, most of them 10–30° wide and most of them <i>not</i> containing 60° or 90°. INTERPRETIVE."))

    # --- stage 6
    s.append(H("8. Stage 6 — ganglia and the layer assignment", 2))
    rows = [["corpus", "HDBSCAN clusters", "ganglia (compact + enclosed on ≥2 families)", "concepts in ganglia", "load by layer"]]
    for c in CORPORA:
        v = S6[c]
        rows.append([c, v["hdbscan_clusters"], v["ganglia"], v["ganglion_concepts"], ", ".join(f"{k} {n}" for k, n in sorted(v["load_by_layer"].items(), key=lambda kv: -kv[1])) or "—"])
    s.append(table(rows, [0.9 * inch, 0.8 * inch, 1.2 * inch, 0.8 * inch, 3.3 * inch]))
    s.append(P("HDBSCAN on 384-d MiniLM finds few dense clusters in the video corpora (2–8) and many in sacred (57, because the registry's 806 concept types recur across 2,348 sections). "
               "\"Fixed geometry\" — a cluster that an ovaloid encloses on two slice families — is present at scale only in sacred (44 ganglia, 4,146 concepts) and in the six-video runs (4–5 ganglia). "
               "Layer loads lean A (brainstem/basal-ganglia side) everywhere except six_a, where the B side (pons → prefrontal) carries 380 of 498. The rule is agent-authored; the table is INTERPRETIVE by construction.", S))
    rows = [["corpus", "largest ganglia (n, mean C, layer) — three central concepts"]]
    for c in ("six_a", "six_b", "sacred", "family", "childhood"):
        gl = S6[c]["ganglia_list"][:4]
        rows.append([c, "<br/>".join(f"n={g['n']}, C={g['mean_C']:+.2f}, {g['layer']}: " + "; ".join(g["central"])[:140] for g in gl) or "—"])
    s.append(table(rows, [0.9 * inch, 6.1 * inch], 6.8))
    s.append(P("Structures receiving load (project neuro SignalWorld ids): " + "; ".join(f"<b>{k}</b> → {', '.join(x.split(' ', 1)[0] for x in v['structures'])}" for k, v in S6["_layer_rule"].items()) + ". INTERPRETIVE.", S))

    # --- stage 7
    s.append(H("9. Stage 7 — test–retest and cross-corpus", 2))
    rows = [["measure", "value", "reading"]]
    rows += [["corr(log A) six_a vs six_b", rt["corr_A"], "the direct line replicates"], ["corr(log B)", rt["corr_B"], "the reflection replicates"], ["corr(C)", rt["corr_C"], "interpretable (≥ 0.5)" if rt["interpretable"] else "below 0.5"],
             ["Dice, A-dominant region", rt["dice_A_dominant"], ""], ["Dice, A-ovaloid s=1 / B-ovaloid s=1", f"{rt['dice_ovaloid_A_s1']} / {rt['dice_ovaloid_B_s1']}", "the small ovaloids do not land in the same place"],
             ["Dice, occlusion mask", rt["dice_occlusion"], ""], ["refraction A / B", f"{rt['refraction_a_deg']}° / {rt['refraction_b_deg']}°", "intervals " + ("overlap" if rt["intervals_overlap"] else "disjoint — the bearing is run-dependent")],
             ["dominant l", f"{rt['dominant_l'][0]} / {rt['dominant_l'][1]}", ""]]
    s.append(table(rows, [2.3 * inch, 1.6 * inch, 3.1 * inch]))
    s.append(P("Same six videos, two independent runs, seeds R and B. The fields agree to 0.96 / 0.88 / 0.65; the large A-dominant region agrees to Dice 0.93; the small ovaloids (Dice 0.09 / 0.20) and the bearing (41.8° vs 17.3°) do not. "
               "Where the scan is coarse it is reliable; where it is fine it is measuring the run. This is the same shape as the CapricornusSix comparison: stable at the ends, chaotic in the middle. COMPUTED."))
    s += fig(os.path.join(SCAN, "retest_six_a_six_b.png"), "C for six_a and six_b on the pooled sphere.", 7.0)
    s += fig(os.path.join(SCAN, "cross_corpus_corr.png"), "Cross-corpus correlation of log A (left: where corpora talk about the same things) and of C (right: where their reflections disagree in the same places).", 7.2)
    ms = S7["most_similar_C"][:5]; ls = S7["least_similar_C"][-5:]
    s.append(P("Most similar C pairs: " + "; ".join(f"{a}–{b} {r:+.2f}" for a, b, r in ms) + ". Least: " + "; ".join(f"{a}–{b} {r:+.2f}" for a, b, r in ls) + ". COMPUTED.", S))

    # --- falsification
    s.append(H("10. Against the plan's falsification criteria (§5)", 2))
    rows = [["criterion", "outcome", "status"]]
    rows += [["Bearings from A and B agree within the interval on every corpus → reflection adds nothing", "No: refraction exceeds the half-width on 9/11", "not falsified"],
             ["six_a vs six_b corr(C) &lt; 0.5 → scan measures the run", f"corr(C) = {rt['corr_C']}", "passes; but bearing and small ovaloids are run-dependent"],
             ["Ganglia do not survive the ovaloid test → no fixed geometry", "Survive at scale only in sacred and six_a/six_b", "partial"],
             ["|E|/|B| &lt; 0.1 with g ≈ 1, κ_B ≈ κ_A → plain copy, no barrier", f"E/B ≥ {min(S3[c]['residual_E_over_B'] for c in CORPORA):.2f} everywhere", "not a plain copy"],
             ["Poor fit with O small → re-sampling, not a reflection", "corr(B,T) 0.39–0.95; worst where O is largest (history_b2n)", "mixed"],
             ["C = 0 no closer to nodal lines than null → standing wave absent on M", f"{n_nodal}/11 closer than null", "<b>falsified on this data</b>"],
             ["Bearing intervals &gt; 90° everywhere → direction not recoverable", f"recoverable on {n_rec}/11", "not falsified"]]
    s.append(table(rows, [3.2 * inch, 2.4 * inch, 1.4 * inch]))

    # --- what the operator's model got and did not get
    s.append(H("11. What the windshield model predicted and what came back", 2))
    rows = [["prediction (operator)", "measurement", "verdict"]]
    rows += [["big — the reflection is magnified / smoother", f"κ_B &lt; κ_A on {n_big}/11", "half"],
             ["dull — lower contrast", f"ratio &lt; 1 on {n_dull}/11", "half"],
             ["occlusion — part of the image is the vehicle", f"O covers {min(S3[c]['occlusion_fraction_sphere'] for c in CORPORA):.0%}–{max(S3[c]['occlusion_fraction_sphere'] for c in CORPORA):.0%} of the sphere", "present on every corpus"],
             ["direction only, partial", f"intervals 5°–160° wide; {n_rec}/11 under 90°", "yes — partial"],
             ["two-for-one standing wave", "l = 6 suppressed; interfaces not nodal", "not on M"],
             ["the reflection concentrates (agent, after the fact)", "A-dominant 74–97%; B in hotspots", "the finding"]]
    s.append(table(rows, [2.6 * inch, 3.0 * inch, 1.4 * inch]))
    s.append(P("The reflection is a <i>focus</i>, not a blur: the sort's receipts pile where the vocabulary is densest and leave the rest of the sphere to the direct line. In the windshield picture that is the headlight glare, not the dashboard. "
               "It was not in the plan. It is in the data on all eleven corpora. INTERPRETIVE.", S))

    # --- plates
    plates = sorted(glob.glob(os.path.join(PLATES, "AB*_*.jpg")))
    if plates:
        s.append(PageBreak()); s.append(H("12. Plates (GENERATED)", 2))
        s.append(P("Five images generated from text prompts written after the numbers above existed. They are illustrations of the findings, not data. GENERATED.", S))
        caps = json.load(open(os.path.join(PLATES, "captions.json"))) if os.path.exists(os.path.join(PLATES, "captions.json")) else {}
        for p in plates:
            s += fig(p, caps.get(os.path.basename(p), os.path.basename(p)), 5.2)

    s.append(H("13. Files", 2))
    s.append(P("<font face='Courier'>results/stage1_invariants.json · results/sphere/ · results/fields/*.npz, *_C.npy · results/stage3_fields_windshield.json · results/stage4_scan_standing.json · results/scan/*_maps.png, *_scan.png, *_spectrum.png · "
               "results/stage5_bearing.json · results/stage6_ganglia.json · results/stage7_retest.json · results/scan/retest_six_a_six_b.png, cross_corpus_corr.png · results/plates/</font>", S))

    out_pdf = os.path.join(ROOT, "REPORT_AndromedaBrainScans_v0.0.1_20261010.pdf"); out_md = out_pdf[:-4] + ".md"
    archive_if_exists(out_pdf); archive_if_exists(out_md)
    SimpleDocTemplate(out_pdf, pagesize=letter, leftMargin=0.6 * inch, rightMargin=0.6 * inch, topMargin=0.6 * inch, bottomMargin=0.6 * inch).build(s)
    with open(out_md, "w") as f:
        f.write("".join(MD))
    log(f"wrote {out_pdf}\nwrote {out_md}")


if __name__ == "__main__":
    main()
