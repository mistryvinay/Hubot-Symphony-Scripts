#    Copyright 2016 The Symphony Software Foundation
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
# Description
#   Queries Zendesk for information about support tickets
#
# Configuration:
#   HUBOT_JIRA_URL (format: "https://jira-domain.com:9090")
#   HUBOT_JIRA_IGNORECASE (optional; default is "true")
#   HUBOT_JIRA_USERNAME (optional)
#   HUBOT_JIRA_PASSWORD (optional)
#   HUBOT_JIRA_ISSUES_IGNORE_USERS (optional, format: "user1|user2", default is "jira|github")
#
# Commands:
#
# Author:
#   stuartf
# Symphony Integration by Vinay Mistry
Entities = require('html-entities').XmlEntities
entities = new Entities()

module.exports = (robot) ->
  cache = []

  # In case someone upgrades form the previous version, we'll default to the
  # previous behavior.
  jiraUrl = process.env.HUBOT_JIRA_URL || "https://#{process.env.HUBOT_JIRA_DOMAIN}"
  jiraUsername = process.env.HUBOT_JIRA_USERNAME
  jiraPassword = process.env.HUBOT_JIRA_PASSWORD

  if jiraUsername != undefined && jiraUsername.length > 0
    auth = "#{jiraUsername}:#{jiraPassword}"

  jiraIgnoreUsers = process.env.HUBOT_JIRA_ISSUES_IGNORE_USERS
  if jiraIgnoreUsers == undefined
    jiraIgnoreUsers = "jira|github"

  robot.http(jiraUrl + "/rest/api/2/project")
    .auth(auth)
    .get() (err, res, body) ->
      json = JSON.parse(body)
      jiraPrefixes = ( entry.key for entry in json )
      reducedPrefixes = jiraPrefixes.reduce (x,y) -> x + "-|" + y
      jiraPattern = "/\\b(" + reducedPrefixes + "-)(\\d+)\\b/g"
      ic = process.env.HUBOT_JIRA_IGNORECASE
      if ic == undefined || ic == "true"
        jiraPattern += "i"

      robot.hear eval(jiraPattern), (msg) ->
#       return if msg.message.user.name.match(new RegExp(jiraIgnoreUsers, "gi"))

        for i in msg.match
          issue = i.toUpperCase()
          now = new Date().getTime()
          if cache.length > 0
            cache.shift() until cache.length is 0 or cache[0].expires >= now

          msg.send item.message for item in cache when item.issue is issue
          if cache.length == 0 or (item for item in cache when item.issue is issue).length == 0
            robot.http(jiraUrl + "/rest/api/2/issue/" + issue)
              .auth(auth)
              .get() (err, res, body) ->
                try
                  json = JSON.parse(body)
                  key = json.key
#        Return Cache Results
                  message = "[ Cache" + key + "] " + json.fields.summary
                  message += '\n Cache Status: ' + json.fields.status.name
#        Return API Results
                  msg.send {
                         format: 'MESSAGEML'
                         text: "<messageML><b>#{key}</b> <b>#{json.fields.summary}</b><br/><i>Status: #{json.fields.status.name.toUpperCase()}    Prio
rity: #{json.fields.priority.name.toUpperCase()}</i><br/><i>Assignee: #{json.fields.assignee.displayName}        Reported By: #{json.fields.reporter.d
isplayName}</i><br/><a href=\"#{entities.encode(jiraUrl)}/browse/#{key}\"/></messageML>"
                  }
#                  cache.push({issue: issue, expires: now + 120000, message: message})
                catch error
                  try
                    msg.send "[*ERROR*] " + json.errorMessages[0]
                  catch reallyError
                    msg.send "[*ERROR*] " + reallyError
