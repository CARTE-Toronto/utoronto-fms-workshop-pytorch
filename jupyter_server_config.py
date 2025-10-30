# Disable unavailable/unused server extensions to silence warnings
c = get_config()  # noqa: F821 - provided by Jupyter at runtime
c.ServerApp.jpserver_extensions = {
    "jupyterlab_tensorboard_pro": False,
    "jupyterlab_tensorboard": False,
}

