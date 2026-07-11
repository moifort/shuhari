import { parseChangelog } from '~/domain/changelog/business-rules'
import { changelogMarkdown } from '~/system/changelog-content'

export namespace ChangelogQuery {
  export const list = async () => parseChangelog(changelogMarkdown)
}
