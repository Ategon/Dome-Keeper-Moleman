extends "res://content/gamemode/prestige/RunFinishedPopup.gd"

func onLeaderboardNotFound():
	scoreUploadMessage = tr("level.gameover.prestige.uploading.mod")
	updateScoreUploadLabel()

func onLeaderboardFound():
	scoreUploadMessage = tr("level.gameover.prestige.uploading.mod")
	updateScoreUploadLabel()
