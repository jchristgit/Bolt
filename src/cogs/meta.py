import discord
import psutil

from discord.ext import commands

import run


class Meta:
    """Meta Commands, providing information about the Bot, and more."""
    def __init__(self, bot):
        self.bot: discord.AutoShardedClient = bot
        self.process = psutil.Process()
        print('Loaded Cog Meta.')

    @staticmethod
    def __unload():
        print('Unloaded Cog Meta.')

    @commands.command()
    async def prefix(self, ctx):
        """Get the prefix which you can use with the Bot."""
        if isinstance(ctx.message.channel, discord.abc.PrivateChannel):
            return await ctx.send(embed=discord.Embed(
                title=('You can use my commands without any prefixes, since we are '
                       'talking in private here. <:poyuW:309409724351119360>'),
                colour=discord.Colour.blue()
            ))

        entry = run.prefixes.find_one(guild_id=ctx.guild.id)
        if entry is None:
            await ctx.send(embed=discord.Embed(
                title=('There is no special prefix configured for this Guild, so you '
                       'can use my default prefixes `?`, `!`, or mention me.'),
                colour=discord.Colour.blue()
            ))
        else:
            await ctx.send(embed=discord.Embed(
                title=(f'My Prefix for this Guild is set to `{entry.prefix}`. Alternatively, you can mention me with '
                       f'your Command. Somebody with the `Manage Messages` permission can change it using '
                       f'`{entry.prefix}setprefix`.'),
                colour=discord.Colour.blue()
            ))

    @commands.command()
    async def stats(self, ctx):
        """Displays information and statistics about the Bot."""
        response = discord.Embed()
        response.colour = discord.Colour.blue()
        response.set_thumbnail(
            url=self.bot.user.avatar_url
        ).set_author(
            name='Made by Volcyy#2359',
            url='https://github.com/Volcyy/Bolt',
            icon_url=(await self.bot.application_info()).owner.avatar_url
        ).add_field(
            name='Guilds',
            value=(f'**Total**: {sum(1 for _ in self.bot.guilds)}\n'
                   f'**Avg. Members**: {sum(g.member_count for g in self.bot.guilds) // len(self.bot.guilds)}\n'
                   f'**Shards**: {self.bot.shard_count}')
        ).add_field(
            name='Users',
            value=(f'**Total**: {sum(1 for _ in self.bot.get_all_members())}\n'
                   f'**Unique**: {len(set(self.bot.get_all_members()))}')
        ).add_field(
            name='System Usage',
            value=(f'**CPU**: {self.process.cpu_percent() / psutil.cpu_count()}%\n'
                   f'**Memory**: {str(self.process.memory_full_info().uss / 1024**2 * 1.048576)[:5]} MB')
        )

        await ctx.send(embed=response)


def setup(bot):
    bot.add_cog(Meta(bot))
