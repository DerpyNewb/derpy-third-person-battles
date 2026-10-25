# Round 67 (2026-10-24): a player's report, the host waiting for the watching partner's HELLO ("no HELLO from 1",
# watching 1). The exe drops every queued push from a machine whose battle +0x3b0 (is_spectator()) is set, so a watcher
# is not waited for and says nothing (Ruling 34, platform.lua M.handshake).
PLAT = "script/derpy_tp/platform.lua"
W = "platform_net_a_watcher_says_nothing_and_is_not_waited_for"
MUTANTS = [
    # the watcher waited for again
    (PLAT, "if p.watching then watching[#watching + 1] = i - 1 else need[#need + 1] = i - 1 end",
     "if p.watching then watching[#watching + 1] = i - 1 end need[#need + 1] = i - 1", W),
    # the watcher says HELLO again
    (PLAT, "if ok and not replay and not why and not sent and not P.net_me.watching then",
     "if ok and not replay and not why and not sent then", W),
    # a list where everyone watches let through: the gate in with nobody heard
    (PLAT, " or #need == 0 and \"everyone in it is watching\"", "", W),
    # a late watcher blames its own HELLO, which it never sends
    (PLAT, "if not P.net_me.watching and not heard(mine) then", "if not heard(mine) then", W),
    # the log no longer says whom it waits for
    (PLAT, " .. \", waits for \" .. list_of(need)", "", W),
]
