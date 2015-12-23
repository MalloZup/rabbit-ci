import DS from 'ember-data';
import ansi_up from 'ansi-up';
import Phoenix from "rabbit-ci/phoenix";

export default DS.Model.extend({
  name: DS.attr('string'),
  status: DS.attr('string'),
  log: DS.attr('string'),
  build: DS.belongsTo('build'),
  htmlLog: Ember.computed(function() {
    return ansi_up.ansi_to_html(this.get('log'), {use_classes: true});
  }).property('log'),

  connectToChan() {
    let socket = this.get('phoenix');
    let chan = socket.channel("steps:" + this.get('id'), {});

    chan.join().receive("ignore", () => console.log("auth error"))
      .receive("ok", () => console.log("connected"));

    chan.onError(e => console.log("something went wrong", e));
    chan.onClose(e => console.log("channel closed", e));

    chan.on("set_log:step", payload => {
      this.set('log', payload["log"]);
    });

    chan.on("append_log:step", payload => {
      this.set('log', this.get('log') + payload["log_append"]);
    });

    this.set('channel', chan);
  },

  disconnectFromChan() {
    let chan = this.get('channel');
    if (chan) chan.leave();
    this.set('channel', null);
  }
});
