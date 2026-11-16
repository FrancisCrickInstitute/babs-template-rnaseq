function Header(el)
  local items = {}

  for k, v in pairs(el.attributes) do
    -- skip empty values
    if v ~= "" then
      -- format: **key**: value
      local content = {
        pandoc.Strong{pandoc.Str(k:lower())},
        pandoc.Str(": "),
        pandoc.Str(v)
      }

      table.insert(items, pandoc.Plain(content))
    end
  end

  if #items > 0 then
    return {
      el,
      pandoc.BulletList(items)
    }
  else
    return el
  end
end
