import common

class Sh(common.CommandRunner):
    def wrap(self, cmd):
        # TODO: wrap with some auth/env if necessary
        return cmd

    def Run(self, cmd):
        self.run_command(self.wrap(cmd))

    def should_pass(self, cmd):
        self.Run(cmd)
        self.return_code_should_be(0)

    def should_fail(self, cmd):
        self.Run(cmd)
        self.return_code_should_not_be(0)
