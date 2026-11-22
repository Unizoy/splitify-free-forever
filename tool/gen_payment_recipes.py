# Generates android/app/src/main/assets/payment_recipes.json (phase 18b, S-221): python tool/gen_payment_recipes.py android/app/src/main/assets/payment_recipes.json
# Patterns are written raw here and dumped as JSON; edit here or in the JSON, then run both vector tests.
import json, sys
CUR = r"(?:₹|\brs\.?|\binr) ?"
AMT = r"(?<amount>[0-9][0-9,]*(?:\.[0-9]{1,2})?)"
ACC = r"[x*]*[0-9]{3,6}"
TERM = r"(?= successfully| on | via | from | using | for | at | upi| ref| txn|\.(?: |$)|[!|,;]|$)"
DEBIT_WORDS = r"\b(?:debited|spent)\b|\bdr\.|\b(?:paid|sent) (?:₹|rs|inr)|(?:₹|rs\.?|inr) ?[0-9][0-9,.]* (?:has been |was )?(?:paid|sent|debited)|\bpaid to\b"
recipes = {
  "version": 1,
  "comment": "Splitify payment capture recipes (phase 18b, S-221). Text is normalised (NBSP/newlines -> one space) and matched case-insensitively. Fix wording here, no code change needed.",
  "maxAmountPaise": 100000000,
  "apps": [
    {"package": "com.google.android.apps.nbu.paisa.user", "name": "Google Pay", "kind": "upi"},
    {"package": "com.phonepe.app", "name": "PhonePe", "kind": "upi"},
    {"package": "net.one97.paytm", "name": "Paytm", "kind": "upi"},
    {"package": "in.org.npci.upiapp", "name": "BHIM", "kind": "upi"},
    {"package": "in.amazon.mShop.android.shopping", "name": "Amazon Pay", "kind": "upi"},
    {"package": "com.dreamplug.androidapp", "name": "CRED", "kind": "upi"},
    {"package": "money.super.payments", "name": "super.money", "kind": "upi"},
    {"package": "com.whatsapp", "name": "WhatsApp", "kind": "upi", "defaultOn": False},
    {"package": "com.google.android.apps.messaging", "name": "Messages", "kind": "sms"},
    {"package": "com.samsung.android.messaging", "name": "Samsung Messages", "kind": "sms"},
    {"package": "com.hdfcbank.android.now", "name": "HDFC Bank", "kind": "bank"},
    {"package": "com.hdfcbank.payzapp", "name": "PayZapp", "kind": "bank"},
    {"package": "com.sbi.lotusintouch", "name": "YONO SBI", "kind": "bank"},
    {"package": "com.csam.icici.bank.imobile", "name": "iMobile", "kind": "bank"},
    {"package": "com.axis.mobile", "name": "Axis Mobile", "kind": "bank"},
    {"package": "com.kotak811mobilebankingapp.instantsavingsupiscanandpayrecharge", "name": "Kotak", "kind": "bank"},
    {"package": "com.msf.kbank.mobile", "name": "Kotak", "kind": "bank"},
    {"package": "com.Version1", "name": "PNB ONE", "kind": "bank"},
    {"package": "com.bankofbaroda.mconnect", "name": "bob World", "kind": "bank"},
    {"package": "com.canarabank.mobility", "name": "Canara ai1", "kind": "bank"},
    {"package": "dev.splitify.fakeupi", "name": "Fake UPI", "kind": "upi", "debugOnly": True},
    {"package": "com.android.shell", "name": "adb", "kind": "sms", "debugOnly": True}
  ],
  "ignore": [
    {"id": "otp", "pattern": r"\botp\b|one[- ]time password|verification code|sensitive notification content hidden"},
    {"id": "failed", "pattern": r"\b(?:failed|failure|declined|unsuccessful|reversed|reversal|cancell?ed)\b|could not be (?:completed|processed)"},
    {"id": "request", "pattern": r"\b(?:has requested|requested|is requesting|collect request|request(?:ing)? money)\b"},
    {"id": "future", "pattern": r"\bwill be (?:debited|deducted|charged)\b|\b(?:is|bill) due\b|\bdue (?:on|by|date)\b|\bupcoming\b|\breminder\b|\bmandate (?:set|created|registered)\b|\bautopay (?:set ?up|activated|registered)\b|\bsetting an autopay\b|\bpending\b"},
    {"id": "credit", "pattern": r"\bto your (?:[a-z]+ )?(?:bank )?(?:a/c|ac|account|wallet)\b|\bcashback of\b"},
    {"id": "credit", "pattern": r"\b(?:credited|deposited|refund(?:ed)?|received)\b|\bmoney received\b", "unless": r"\b(?:debited|spent)\b|\bdr\.|\b(?:paid|sent) (?:₹|rs|inr)|(?:₹|rs\.?|inr) ?[0-9][0-9,.]* (?:has been |was )?(?:paid|sent)"},
    {"id": "promo", "pattern": r"\b(?:win|won|offer|offers|voucher|coupon|reward|rewards|scratch card|apply now|pre-approved|lifetime free|cashback)\b", "unless": DEBIT_WORDS}
  ],
  "debit": [
    {"id": "sent_from_to", "pattern": r"\bsent " + CUR + AMT + r" from .{1,40}? to (?<payee>.+?) on [0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4}\b"},
    {"id": "sbi_trf", "pattern": r"a/c " + ACC + r" debited by (?:" + CUR + r")?" + AMT + r" on date [0-9a-z]{5,9} trf to (?<payee>.+?) ref ?no\b"},
    {"id": "debited_paid_to", "pattern": CUR + AMT + r" debited from a/c " + ACC + r" and paid to (?<payee>.+?)\.? (?:upi )?ref\b"},
    {"id": "debited_from_on_to", "pattern": CUR + AMT + r" (?:has been )?debited from (?:your )?(?:a/c|ac|account|acct)(?: no\.?)? " + ACC + r" on [0-9a-z/-]{5,11} to (?<payee>.+?) \(?(?:upi )?ref\b"},
    {"id": "icici_debited_for", "pattern": r"acc(?:t|ount)? " + ACC + r" debited (?:for|with) " + CUR + AMT + r" on [0-9a-z-]{7,11}; (?<payee>.+?) credited\."},
    {"id": "pnb_debited", "pattern": r"a/c " + ACC + r" debited " + CUR + AMT + r" (?:dt [0-9-]{8,10} [0-9:]{8} )?to (?<payee>.+?) thru upi\b"},
    {"id": "canara_dr", "pattern": r"acct " + ACC + r" dr\. " + CUR + AMT + r" on [0-9/-]{8,10} to (?<payee>.+?)[;,] upi\b"},
    {"id": "bob_dr_cr", "pattern": CUR + AMT + r" dr\. from a/c " + ACC + r" and cr\. to (?<payee>.+?)\.? ref\b"},
    {"id": "axis_upi", "pattern": CUR + AMT + r" debited a/c no\. " + ACC + r" [0-9-]{8,10},? [0-9:]{8} upi/p2[am]/(?<ref>[0-9]{6,20})/(?<payee>[^/]+?)(?= not you|/|$)"},
    {"id": "axis_debited_on", "pattern": CUR + AMT + r" debited from a/c no\. [^ ]+ on (?<payee>.+?) [0-9]{2}-[0-9]{2}-[0-9]{4} [0-9:]{8} ist\b"},
    {"id": "card_spent_on_card_at", "pattern": r"\bspent " + CUR + AMT + r" on .{3,40}? card [x*]*[0-9]{4} at \.*(?<payee>.+?) on [0-9]"},
    {"id": "card_spent_using_at", "pattern": r"\bspent " + CUR + AMT + r" using .{3,40}? card no\. " + ACC + r" on .{8,30}? at (?<payee>.+?)\.(?: |$)"},
    {"id": "card_spent_ending", "pattern": CUR + AMT + r" spent on your .{3,30}? card ending (?:with )?[0-9]{4}(?: at (?<payee>.+?))? on [0-9]"},
    {"id": "card_spent_using_on", "pattern": CUR + AMT + r" spent using .{3,30}? card " + ACC + r" on [0-9a-z-]{7,11} on (?<payee>.+?)\.(?: |$)"},
    {"id": "payment_of_to", "pattern": r"\bpayment of " + CUR + AMT + r" (?:made )?to (?<payee>.+?) (?:is |was |has been )?(?:successful|completed|done|success)\b"},
    {"id": "app_paid_to", "pattern": r"\b(?:paid|sent) " + CUR + AMT + r" (?:successfully )?to (?<payee>.+?)" + TERM},
    {"id": "app_amount_paid_to", "pattern": CUR + AMT + r" (?:has been |was )?(?:paid|sent|transferred)(?: successfully)? to (?<payee>.+?)" + TERM}
  ],
  "refs": [
    r"(?:upi transaction id|transaction id|txn id|upi ref(?:erence)?(?: no| number| id)?|ref(?:erence)?(?: no| number| id)?|refno|utr|rrn|upi)[.:# ]{0,3}(?<ref>[0-9]{6,20})\b"
  ],
  "payeeReject": r"^(?:you|me|self|your\b.*)$",
  "screen": {
    "pin": r"\bupi pin\b|\benter (?:your )?(?:upi )?pin\b",
    "paying": r"\b(?:proceed to pay|pay securely|pay now|paying)\b|\bpay ₹",
    "success": [
      {"id": "screen_amount_paid_to", "pattern": CUR + AMT + r" (?:paid|sent)(?: successfully)? to (?<payee>.+?)(?= [a-z0-9._-]+@[a-z]+| upi| from | on | done| share|$)"},
      {"id": "screen_paid_to_amount", "pattern": r"(?:paid|sent) to (?<payee>.+?) " + CUR + AMT + r"(?= |$)"}
    ]
  }
}
out = sys.argv[1]
with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(recipes, f, ensure_ascii=False, indent=2)
    f.write("\n")
