# === HappyScale-Style Trend Playground (Local VS Code, No Pandas/Numpy) ===
# Copy & paste entire cell into a VS Code .ipynb notebook

import csv
import math
import datetime as dt
import matplotlib.pyplot as plt

# ------------------------------------------------------------
# 1. SET YOUR CSV PATH HERE (change YOURNAME → your Mac username)
# ------------------------------------------------------------
CSV_PATH = r"/Users/alexsweet/Documents/Swift experiment/nutribase copy/weights 3.csv"   # ← CHANGE THIS


# ------------------------------------------------------------
# 2. LOAD CSV ("Date", "Recorded")
# ------------------------------------------------------------
dates = []
weights = []

with open(CSV_PATH, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        date_str = row["Date"].strip()
        weight_str = row["Recorded"].strip()

        # Parse date
        try:
            d = dt.datetime.strptime(date_str, "%Y-%m-%d")
        except:
            d = dt.datetime.fromisoformat(date_str)

        dates.append(d)
        weights.append(float(weight_str))

if not dates:
    raise ValueError("No data loaded — check the file path and CSV header names.")

print(f"Loaded {len(weights)} weight entries.")


# ------------------------------------------------------------
# 3. HAPPY SCALE–LIKE SMOOTHING FUNCTIONS (NO DEPENDENCIES)
# ------------------------------------------------------------
def double_exponential_smoothing_tp(values, alpha, beta, turning_point_factor):
    """
    Holt Double Exponential Smoothing + turning point damping.
    """
    n = len(values)
    if n < 2:
        return values[:]

    level = values[0]
    trend = values[1] - values[0]
    result = [0.0] * n

    prev_delta = values[1] - values[0]

    for i in range(n):
        x = values[i]

        delta = x - values[i - 1] if i > 0 else prev_delta

        # Turning point detected (sign flip)
        turning = (
            i > 1
            and math.copysign(1.0, delta) != math.copysign(1.0, prev_delta)
            and delta != 0
            and prev_delta != 0
        )

        # Dampen beta around turning points
        if turning:
            clamp = max(0.0, min(1.0, turning_point_factor))
            reduction = 0.1 + 0.7 * clamp  # reduces β by 10–80%
            beta_eff = beta * (1.0 - reduction)
        else:
            beta_eff = beta

        prev_level = level
        level = alpha * x + (1 - alpha) * (level + trend)
        trend = beta_eff * (level - prev_level) + (1 - beta_eff) * trend

        result[i] = level + trend
        prev_delta = delta

    return result


def moving_average(values, window):
    """
    Centered moving average with odd window size.
    """
    n = len(values)
    if window <= 1:
        return values[:]

    if window % 2 == 0:
        window += 1

    radius = window // 2
    out = [0.0] * n

    for i in range(n):
        start = max(0, i - radius)
        end = min(n - 1, i + radius)
        chunk = values[start:(end + 1)]
        out[i] = sum(chunk) / len(chunk)

    return out


def build_trend(values, alpha, beta, window, turning_point_factor):
    """
    Full HappyScale-like smoothing pipeline:
    1) DES + turning damping
    2) Light moving-average polish
    """
    des = double_exponential_smoothing_tp(
        values,
        alpha=alpha,
        beta=beta,
        turning_point_factor=turning_point_factor
    )
    polished = moving_average(des, window)
    return polished


# ------------------------------------------------------------
# 4. PLOTTING FUNCTION
# ------------------------------------------------------------
def plot_trend(alpha=0.22, beta=0.08, window=7, turning=0.3):
    trend = build_trend(weights, alpha, beta, window, turning)

    fig, ax = plt.subplots(figsize=(12, 5))

    # Raw weight data
    ax.plot(dates, weights, color="lightgray", alpha=0.7, linewidth=1, label="Raw")

    # Smoothed trend line
    ax.plot(dates, trend, color="tab:blue", linewidth=2.5, label="Trend")

    ax.set_title(f"HappyScale-Style Trend\nα={alpha:.2f}  β={beta:.2f}  window={window}  turning={turning:.2f}")
    ax.grid(True, alpha=0.3)
    ax.set_ylabel("Weight")
    ax.legend()
    fig.autofmt_xdate()
    plt.tight_layout()
    plt.show()


# ------------------------------------------------------------
# 5. GENERATE COMPARISON PLOTS
# ------------------------------------------------------------
def plot_comparison():
    """Generate 4 plots with different smoothing levels for comparison."""
    configs = [
        {"name": "HappyScale Default", "alpha": 0.22, "beta": 0.08, "window": 7, "turning": 0.3},
        {"name": "Ultra Smooth", "alpha": 0.15, "beta": 0.05, "window": 11, "turning": 0.5},
        {"name": "Responsive", "alpha": 0.30, "beta": 0.12, "window": 5, "turning": 0.2},
        {"name": "Very Smooth", "alpha": 0.18, "beta": 0.06, "window": 9, "turning": 0.4},
    ]
    
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    axes = axes.flatten()
    
    for idx, config in enumerate(configs):
        trend = build_trend(weights, config["alpha"], config["beta"], config["window"], config["turning"])
        
        ax = axes[idx]
        ax.plot(dates, weights, color="lightgray", alpha=0.5, linewidth=1, label="Raw")
        ax.plot(dates, trend, color="tab:blue", linewidth=2.5, label="Trend")
        
        title = f"{config['name']}\nα={config['alpha']:.2f}  β={config['beta']:.2f}  window={config['window']}  turning={config['turning']:.2f}"
        ax.set_title(title, fontsize=11, fontweight='bold')
        ax.grid(True, alpha=0.3)
        ax.set_ylabel("Weight")
        ax.legend(loc='upper right')
        ax.tick_params(axis='x', rotation=45)
    
    plt.tight_layout()
    plt.show()

print("\nGenerating comparison plots with different smoothing levels...\n")
plot_comparison()

print("\n" + "="*70)
print("To try custom parameters, use:")
print("plot_trend(alpha=0.22, beta=0.08, window=7, turning=0.3)")
print("="*70)
