class Dashing.TeamCity extends Dashing.Widget
    onData: (data) ->
        if data.project.status == "SUCCESS"
            $(@node).css("background-color": "green")
        else if data.project.status == "FAILURE"
            $(@node).css("background-color": "red")
