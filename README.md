# Chatbot

This is a sample chatbot for Google Hangouts Chat written in Elixir, using
the Phoenix framework. This application comes with a Dockerfile and is
ready to be packaged as a container and is perfect for running in your
serverless environment.

This application was written as a demo for Cloud Next '19

# Dependencies

The chatbot is meant to receive messages from
[Google Hangouts Chat](https://developers.google.com/hangouts/chat/).

There is a runtime dependcy on [Cloud Firestore](https://cloud.google.com/firestore/)
in *Datastore Mode*.

The chatbot also depends on a meme service, and by default uses the one hosted
at https://meme-fpz6derz7a-uc.a.run.app

# Build

1. Generate a new secret key base.

```shell
 SECRET_KEY_BASE=$(elixir -e ":crypto.strong_rand_bytes(48) |> Base.encode64 |> IO.puts")
 sed "s|SECRET+KEY+BASE|$SECRET_KEY_BASE|" config/prod.secret.exs.sample >config/prod.secret.exs
 ```

1. To build with Google [Cloud Build](https://cloud.google.com/cloud-build/),
simply issue this [gcloud](https://cloud.google.com/sdk/gcloud/) command.

```
gcloud builds submit --tag=gcr.io/<GOOGLE CLOUD PROJECT>/chatbot:v1 .
```

# Deploy

TODO(mikehelmlick): Deploy instructions coming soon!
