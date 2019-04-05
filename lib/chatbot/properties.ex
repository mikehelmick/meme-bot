defmodule Chatbot.Properties do
  @moduledoc """
  This module is useful for manipulating Google Cloud Firestore in Datastore
  mode Properties.
  """

  def set_string_property(props, _key, nil), do: props
  def set_string_property(props, key, val) do
    Map.put(props, key,
      %GoogleApi.Datastore.V1.Model.Value {
        stringValue: val
      })
  end

  def setUnindexedString(props, _key, nil), do: props
  def setUnindexedString(props, key, val) do
    Map.put(props, key,
      %GoogleApi.Datastore.V1.Model.Value {
        excludeFromIndexes: true,
        stringValue: val
      })
  end

  def set_boolean_property(props, _key, nil), do: props
  def set_boolean_property(props, key, val) when is_boolean(val) do
    Map.put(props, key,
      %GoogleApi.Datastore.V1.Model.Value {
        booleanValue: val
      })
  end

  def set_datetime_property(props, _key, nil), do: props
  def set_datetime_property(props, key, val) do
    Map.put(props, key,
      %GoogleApi.Datastore.V1.Model.Value {
        timestampValue: val
      })
  end

  def set_integer_property(props, _key, nil), do: props
  def set_integer_property(props, key, val) when is_integer(val) do
    Map.put(props, key,
      %GoogleApi.Datastore.V1.Model.Value {
        integerValue: Integer.to_string(val)
      })
  end

  def parse_string(map), do: parse_string(map, "")
  def parse_string(%{"stringValue" => val}, _default), do: val
  def parse_string(_, default), do: default

  def parse_bool(map), do: parse_bool(map, false)
  def parse_bool(%{"booleanValue" => true}, _default), do: true
  def parse_bool(%{"booleanValue" => false}, _default), do: false
  def parse_bool(_, default), do: default

  def parse_int(map), do: parse_int(map, 0)
  def parse_int(%{"integerValue" => val}, _default), do: String.to_integer(val)
  def parse_int(_, default), do: default

  def parse_timestamp(map), do: parse_timestamp(map, DateTime.utc_now())
  def parse_timestamp(%{"timestampValue" => val}, _default) do
    {:ok, dt_value, _} = DateTime.from_iso8601(val)
    dt_value
  end
  def parse_timestamp(_, default), do: default
end
