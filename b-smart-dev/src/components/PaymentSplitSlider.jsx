// Replaces the old "Wallet vs Razorpay" radio buttons with a single drag bar:
// coins are applied first (up to the wallet balance), and whatever's left is
// charged via Razorpay. Dragging all the way right uses all available coins
// (or the full total, whichever is smaller); all the way left pays entirely
// via Razorpay.
export default function PaymentSplitSlider({ totalAmount, walletBalance, value, onChange }) {
  const maxCoins = Math.max(0, Math.min(walletBalance, totalAmount));
  const coins = Math.max(0, Math.min(value, maxCoins));
  const razorpayAmount = Math.max(0, totalAmount - coins);
  const progress = maxCoins > 0 ? (coins / maxCoins) * 100 : 0;

  if (totalAmount <= 0) return null;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between text-sm font-semibold text-gray-900 dark:text-white">
        <span>Coins: ₹{coins.toLocaleString()}</span>
        <span>Razorpay: ₹{razorpayAmount.toLocaleString()}</span>
      </div>
      <input
        type="range"
        min={0}
        max={maxCoins}
        step={1}
        value={coins}
        onChange={(event) => onChange(Number(event.target.value))}
        disabled={maxCoins <= 0}
        aria-label="How much of the total to pay with coins"
        className="w-full accent-[#fa3f5e] disabled:opacity-40"
        style={{ background: `linear-gradient(to right, #fa3f5e ${progress}%, #e5e7eb ${progress}%)` }}
      />
      <p className="text-[11px] text-gray-500 dark:text-gray-400">
        {maxCoins <= 0
          ? 'No wallet balance available — this order will be paid entirely via Razorpay.'
          : `Drag to choose how much of ₹${totalAmount.toLocaleString()} to pay with coins (you have ₹${walletBalance.toLocaleString()}). The rest is charged via Razorpay.`}
      </p>
    </div>
  );
}
