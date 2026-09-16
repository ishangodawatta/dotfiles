return {
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall" },
    opts = {
      ensure_installed = { "debugpy" },
    },
  },
}
