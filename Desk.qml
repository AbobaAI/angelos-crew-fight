pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

// Shared by the desktop widget (two copies) and Main: who sits in the two cells.
QtObject {
    id: root

    property bool expanded: false
    property var a: null
    property var b: null
    signal fightAsked()

    function put(slot, who) {
        if (!who || !who.id)
            return;
        if (slot === 0) {
            if (b && b.id === who.id)
                b = null;
            a = who;
        } else {
            if (a && a.id === who.id)
                a = null;
            b = who;
        }
    }
    function clear(slot) {
        if (slot === 0)
            a = null;
        else
            b = null;
    }
    function ask() {
        if (a && b && a.id !== b.id)
            fightAsked();
    }
}
