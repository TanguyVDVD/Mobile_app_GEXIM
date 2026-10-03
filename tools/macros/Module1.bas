Option Explicit

' Bouton « Nouveau point ».
'
' Crée la fiche d'un nouveau point : une feuille au nom du numéro saisi, qui
' ne reprend de la feuille active que ce qui est commun au chantier — numéro
' et intitulé du projet, Purchase Order, bâtiment, client (logo et adresse) —
' avec la date du jour et le numéro saisi. Tout ce qui est propre au point de
' départ est vidé : étage, photos, caractéristiques, produits.
Sub nvx_pt()
    Dim numero As String

    numero = Trim(InputBox("Entrez le numéro du nouveau point :", "Nouveau point"))

    If numero = "" Then
        MsgBox "Aucun numéro saisi. La création a été annulée.", vbExclamation
        Exit Sub
    End If

    If creer_point(numero) Then
        MsgBox "La fiche du point " & numero & " a été créée.", vbInformation
    Else
        MsgBox "« " & numero & " » n'est pas un nom de feuille valide, ou une " & _
               "feuille porte déjà ce nom. Aucune fiche n'a été créée.", vbExclamation
    End If
End Sub

' Le travail de « Nouveau point », sans aucune boîte de dialogue.
' Rend False, sans rien laisser derrière elle, si la feuille n'a pas pu
' prendre le numéro pour nom.
Function creer_point(numero As String) As Boolean
    Dim depart As Worksheet
    Dim fiche As Worksheet
    Dim i As Long

    Set depart = ActiveSheet
    Application.ScreenUpdating = False

    ' La copie garde la mise en forme, les listes déroulantes, les boutons,
    ' la zone d'impression et le logo du client.
    depart.Copy After:=depart
    Set fiche = ActiveSheet

    On Error Resume Next
    fiche.Name = numero
    On Error GoTo 0

    If fiche.Name <> numero Then
        Application.DisplayAlerts = False
        fiche.Delete
        Application.DisplayAlerts = True
        depart.Activate
        Application.ScreenUpdating = True
        creer_point = False
        Exit Function
    End If

    With fiche
        ' Le numéro du point : en M5, d'où la fiche le reprend (numéro de
        ' fiche en G5, « Numéro du point » en E15).
        .Range("M5").NumberFormat = "@"
        .Range("M5").Value = numero
        .Range("E15:H15").Merge
        .Range("E15").NumberFormat = "General"
        .Range("E15").Formula = "=M5"
        .Range("E15:H15").HorizontalAlignment = xlLeft

        .Range("D5").Value = Date

        ' Ce qui appartenait au point de départ.
        .Range("E14:H14").ClearContents
        .Range("C18:E18").ClearContents
        .Range("F18:H18").ClearContents
        .Range("F20:H29").ClearContents

        ' Ses photos : les images posées sur les deux cases photo. Le logo du
        ' client, ligne 7, reste — mais Excel rétrécit à la copie l'image de
        ' la case « Client », liée à K7 : elle est recalée sur sa case.
        For i = .Shapes.Count To 1 Step -1
            If .Shapes(i).Type = msoPicture Or .Shapes(i).Type = msoLinkedPicture Then
                If Not Intersect(.Shapes(i).TopLeftCell, .Range("C18:H18")) Is Nothing Then
                    .Shapes(i).Delete
                ElseIf Not Intersect(.Shapes(i).TopLeftCell, .Range("D7:E8")) Is Nothing Then
                    remplir_case .Shapes(i), .Range("D7:E8")
                End If
            End If
        Next i

        .Range("E14").Select
    End With

    Application.ScreenUpdating = True
    creer_point = True
End Function

' Donne à une image les dimensions d'une case, en laissant voir ses traits.
Private Sub remplir_case(image As Shape, zone As Range)
    Const RETRAIT As Double = 1.5

    With image
        .LockAspectRatio = msoFalse
        .Left = zone.Left + RETRAIT
        .Top = zone.Top + RETRAIT
        .Width = zone.Width - 2 * RETRAIT
        .Height = zone.Height - 2 * RETRAIT
        .Placement = xlMoveAndSize
    End With
End Sub
