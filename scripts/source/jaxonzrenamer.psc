Scriptname JaxonzRenamer extends Quest
{Renames objects in game}

import Debug
import Utility
import Game
import Input
Import UI
Import StringUtil

GlobalVariable Property giRenameHotkey Auto
GlobalVariable Property giEnforceRenaming Auto
MiscObject Property frmRenamerLocation Auto
MiscObject Property frmRenamerToken Auto
FormList Property flstRenamerTokens Auto
FormList Property flstRenamedForms Auto
Bool Property bUndoingAll Auto
Bool bRenameGlobally

Form frmInventoryItemSelected

Event OnInit()
        UpdateSettings()
EndEvent

Function UpdateSettings()
    UnregisterForAllKeys()
    UnregisterForAllMenus()
    UnregisterForAllModEvents()
    RegisterForKey(giRenameHotkey.GetValueInt())
    RegisterForMenu("InventoryMenu")
    RegisterForModEvent("MYPREFIX_selectionChange", "OnItemSelectionChange")
EndFunction

Event OnKeyDown(Int KeyCode)
    ObjectReference objRename
    String sRenameMessagePrefix
    String sOriginalName
    
    if IsKeyPressed(54) || IsKeyPressed(42) ;if left or right shift is held down
        bRenameGlobally = true
        sRenameMessagePrefix = "Globally Rename "
    Else
        bRenameGlobally = false
        sRenameMessagePrefix = "Rename Object "
    EndIf
    
    if bRenameGlobally
        if !IsInMenuMode() ;only pay attention to hotkeys in game mode
            objRename = GetCurrentCrosshairRef()
            if !objRename
                objRename = GetCurrentConsoleRef()
            EndIf
            
            if objRename    ;rename targeted ObjectReference
                Notification("Renaming targeted object...")
                sOriginalName = objRename.GetBaseObject().GetName()
                
                string strDisplayName = ((Self as Form) as UILIB_1).ShowTextInput(sRenameMessagePrefix + sOriginalName + " to...", "")
                if strDisplayName != ""
                    RenameBaseForm(objRename.GetBaseObject(), strDisplayName)
    
                    ;quickly open and close the menu to cause name to refresh
                    SetFloat("TweenMenu", "_root.TweenMenu_mc._alpha", 0.0)
                    InvokeString("HUD Menu", "_global.skse.OpenMenu", "TweenMenu")
                    WaitMenuMode(0.005)
                    InvokeString("HUD Menu", "_global.skse.CloseMenu", "TweenMenu")
                EndIf
            Else    ;prompt to rename the current location
                Notification("Renaming current location...")
                RenameCurrentLocation(((Self as Form) as UILIB_1).ShowTextInput("Rename Location " + GetPlayer().GetCurrentLocation().GetName() + " to...", ""))
            EndIf
        ElseIf UI.IsMenuOpen("InventoryMenu") && frmInventoryItemSelected   ;rename inventory items
            objRename = GetPlayer().DropObject(frmInventoryItemSelected)
            sOriginalName = frmInventoryItemSelected.GetName()
            string strDisplayName = ((Self as Form) as UILIB_1).ShowTextInput(sRenameMessagePrefix + sOriginalName + " to...", "")
            if strDisplayName != ""
                RenameBaseForm(frmInventoryItemSelected, strDisplayName)
            EndIf
            GetPlayer().AddItem(objRename)
            frmInventoryItemSelected = none
        ElseIf UI.IsMenuOpen("Console") ;rename other forms
            
            string strFormID = ((Self as Form) as UILIB_1).ShowTextInput("Close console (~), enter the Form ID to rename", "")
            if strFormID != ""
                Form frmRename = GetFormEx(HexStringToInteger(strFormID))
                if frmRename
                    string strDisplayName = ((Self as Form) as UILIB_1).ShowTextInput(sRenameMessagePrefix + frmRename.GetName() + " to...", "")
                    if strDisplayName != ""
                        RenameBaseForm(frmRename, strDisplayName)
                    EndIf
                Else
                    Notification(strFormID + " is not a valid FormID. Use the console help command to identify a valid FormID")
                EndIf
            EndIf
        EndIf   
    
    Else    ;not global rename
        if !IsInMenuMode() ;only pay attention to hotkeys in game mode
            objRename = GetCurrentCrosshairRef()
            if !objRename
                objRename = GetCurrentConsoleRef()
            EndIf
            
            if objRename    ;rename targeted ObjectReference
                Notification("Renaming targeted object...")
                sOriginalName = objRename.GetDisplayName()
                
                string strDisplayName = ((Self as Form) as UILIB_1).ShowTextInput(sRenameMessagePrefix + sOriginalName + " to...", "")
                if strDisplayName != ""
                    RenameObjectRef(objRename, strDisplayName)
    
                    ;quickly open and close the menu to cause name to refresh
                    SetFloat("TweenMenu", "_root.TweenMenu_mc._alpha", 0.0)
                    InvokeString("HUD Menu", "_global.skse.OpenMenu", "TweenMenu")
                    WaitMenuMode(0.005)
                    InvokeString("HUD Menu", "_global.skse.CloseMenu", "TweenMenu")
                EndIf
            Else    ;prompt to rename the current location
                Notification("No item selected.\nTo rename the current location, hold Shift + Renamer hotkey.")
            EndIf
        ElseIf UI.IsMenuOpen("InventoryMenu") && frmInventoryItemSelected   ;rename inventory items
            objRename = GetPlayer().DropObject(frmInventoryItemSelected)
            sOriginalName = objRename.GetDisplayName()
            string strDisplayName = ((Self as Form) as UILIB_1).ShowTextInput(sRenameMessagePrefix + sOriginalName + " to...", "")
            if strDisplayName != ""
                RenameObjectRef(objRename, strDisplayName)
            EndIf
            GetPlayer().AddItem(objRename)
            frmInventoryItemSelected = none
        EndIf   
    EndIf
    
EndEvent

Function RenameObjectRef(ObjectReference objRef, String strNewName)
    if objRef && (strNewName != "")
        JaxonzRenamerObjectToken objRenamer = GetPlayer().PlaceAtMe(frmRenamerToken, 1, true) as JaxonzRenamerObjectToken
        
        objRenamer.objRef = objRef
        objRenamer.strOriginalName = objRef.GetDisplayName()
        objRenamer.strNewName = strNewName
        
        flstRenamerTokens.AddForm(objRenamer)
        
        ;check for success
        if objRenamer.ApplyNewName()
            string sCantRenameMessage = "Jaxonz Renamer was unable to rename " + objRenamer.strOriginalName + " to " + objRenamer.strNewName + ".\n"
            
            if objRef.GetNumReferenceAliases()
                sCantRenameMessage += "One or more ReferenceAliases link to it and may override the displayed name.\n" + \
                    "A message box will be displayed for each linked ReferenceAlias."
            Else
                sCantRenameMessage += "No current ReferenceAliases link to it, but one may have in the past and still overrides naming."
            EndIf
            MessageBox(sCantRenameMessage + "\n\nJaxonz Renamer is tenacious. It will continue to attempt applying the new name.")
            
            ;check if this object is a ref Alias
            int iRefs = objRef.GetNumReferenceAliases()
            string sRefInfo
            While iRefs
                iRefs -= 1
                ReferenceAlias refAlias = objRef.GetNthReferenceAlias(iRefs)
                sRefInfo = "\nis referenced by\n" + refAlias.GetName() + "\nin quest\n" + refAlias.GetOwningQuest().GetID() + "\nof mod\n" + Game.GetModName(Math.RightShift(refAlias.GetOwningQuest().GetFormID(),24)) 
                MessageBox(objRef.GetDisplayName() + sRefInfo)
                Trace(objRef + sRefInfo)
            EndWhile
        EndIf           
    EndIf
EndFunction

Function RenameCurrentLocation(String strNewName)
    if strNewName != ""
        Cell celCurrent = GetPlayer().GetParentCell()
        Location locCurrent = GetPlayer().GetCurrentLocation()
        ;celCurrent.SetName(strDisplayName)
        JaxonzRenamerLocationObject objLocRenamer = GetPlayer().PlaceAtMe(frmRenamerLocation, 1, true) as JaxonzRenamerLocationObject
        objLocRenamer.locLocation = locCurrent
        objLocRenamer.celCellList[0] = celCurrent
        objLocRenamer.strOriginalName = locCurrent.GetName()
        objLocRenamer.strNewName = strNewName
        flstRenamerTokens.AddForm(objLocRenamer)
        objLocRenamer.ApplyNewName()
    EndIf
EndFunction

Function RenameBaseForm(Form frmBase, String strNewName)
    if frmBase && (strNewName != "")
        JaxonzRenamerObjectToken objRenamer = GetPlayer().PlaceAtMe(frmRenamerToken, 1, true) as JaxonzRenamerObjectToken
        
        objRenamer.frmBase = frmBase
        objRenamer.strOriginalName = frmBase.GetName()
        objRenamer.strNewName = strNewName
        
        flstRenamerTokens.AddForm(objRenamer)
        flstRenamedForms.AddForm(objRenamer)
        
        ;check for success
        if objRenamer.ApplyNewName()
            string sCantRenameMessage = "Jaxonz Renamer was unable to rename " + objRenamer.strOriginalName + " to " + objRenamer.strNewName + ".\n"        
            MessageBox(sCantRenameMessage + "\n\nJaxonz Renamer is tenacious. It will continue to attempt applying the new name.")
        EndIf
    EndIf
EndFunction


Function ReapplyNewNames()
;Notification("Renamer reapplying new names..")
    if giEnforceRenaming.GetValueInt()
        Trace("JaxonzRenamer ReapplyNewNames begin")
        int iIndex = 0
        While iIndex < flstRenamerTokens.GetSize()
            JaxonzRenamerObject objRenamer = flstRenamerTokens.GetAt(iIndex) as JaxonzRenamerObject
            if (objRenamer as JaxonzRenamerLocationObject)
                (objRenamer as JaxonzRenamerLocationObject).ApplyNewName()
            Else
                (objRenamer as JaxonzRenamerObjectToken).ApplyNewName()
            EndIf
            iIndex += 1
        Trace("JaxonzRenamer ReapplyNewNames ApplyNewName: " + objRenamer.strNewName)
        EndWhile
        Trace("JaxonzRenamer ReapplyNewNames finished")
    EndIf
    
    ;always reapply renamed forms
    Trace("JaxonzRenamer ReapplyNewNames begin renaming forms")
    int iFormIndex = 0
    While iFormIndex < flstRenamedForms.GetSize()
        JaxonzRenamerObject objRenamer = flstRenamedForms.GetAt(iFormIndex) as JaxonzRenamerObjectToken
        objRenamer.ApplyNewName()
        iFormIndex += 1
    Trace("JaxonzRenamer ReapplyNewNames ApplyNewName form: " + objRenamer.strNewName)
    EndWhile
    Trace("JaxonzRenamer ReapplyNewNames finished")

EndFunction

event OnMenuOpen(string a_MenuName)
    string[] args = new string[2]
    args[0] = "itemSelectionMonitorContainer"
    args[1] = "-16380"

    ; Create empty container clip
    InvokeStringA("InventoryMenu", "_root.createEmptyMovieClip", args)
    ; Load SWF into container
    InvokeString("InventoryMenu", "_root.itemSelectionMonitorContainer.loadMovie", "SelectedItemMonitor.swf")
endEvent

event OnItemSelectionChange(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
    frmInventoryItemSelected = a_sender
;   Notification("Selected " + a_sender.GetName())
endEvent

Int Function HexStringToInteger(String strHex)
;converts a hex string to integer equivalent
;useful for instantiating forms from user input
    Int iStrLen = GetLength(strHex)
    Int iCurrentPosition
    Int iReturnValue
    String sCurrentDigit
    Int iCurrentValue
    
    While (iCurrentPosition < iStrLen)
        sCurrentDigit = GetNthChar(strHex, iCurrentPosition)
        
        If IsDigit(sCurrentDigit)
            iCurrentValue = sCurrentDigit as int
        ElseIf (sCurrentDigit == "A") || (sCurrentDigit == "a")
            iCurrentValue = 10 
        ElseIf (sCurrentDigit == "B") || (sCurrentDigit == "b")
            iCurrentValue = 11
        ElseIf (sCurrentDigit == "C") || (sCurrentDigit == "c")
            iCurrentValue = 12
        ElseIf (sCurrentDigit == "D") || (sCurrentDigit == "d")
            iCurrentValue = 13
        ElseIf (sCurrentDigit == "E") || (sCurrentDigit == "e")
            iCurrentValue = 14
        ElseIf (sCurrentDigit == "F") || (sCurrentDigit == "f")
            iCurrentValue = 15
        Else    ;ignores invalide characters, which allows for inputs like "0x00012AB7"
            iCurrentValue= 0
        EndIf

        iCurrentValue = iCurrentValue * Math.pow(16, (iStrLen - (iCurrentPosition + 1))) as int ;multiply the value times the hex power due to position
;Trace("HexStringToInteger - iCurrentPosition: " + iCurrentPosition + ", sCurrentDigit: " + sCurrentDigit + ", iCurrentValue: " + iCurrentValue)
        iReturnValue += iCurrentValue   ;accumulate the total value
        iCurrentPosition += 1
    EndWhile

Trace("HexStringToInteger - strHex: " + strHex + ", iReturnValue: " + iReturnValue)

    return iReturnValue
EndFunction