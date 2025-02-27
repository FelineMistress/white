import { filter, uniqBy } from 'common/collections';
import { flow } from 'common/fp';
import { classes } from 'common/react';
import { capitalize } from 'common/string';
import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Box, Button, Collapsible, Dimmer, Divider, Dropdown, Flex, Icon, LabeledList, NumberInput, ProgressBar, Section, Stack } from '../components';
import { Window } from '../layouts';

const SUBJECT_CONCIOUS = 0;
const SUBJECT_SOFT_CRIT = 1;
const SUBJECT_UNCONSCIOUS = 2;
const SUBJECT_DEAD = 3;
const SUBJECT_TRANSFORMING = 4;

const GENES = ['A', 'T', 'C', 'G'];
const GENE_COLORS = {
  A: 'green',
  T: 'green',
  G: 'blue',
  C: 'blue',
  X: 'grey',
};

const CONSOLE_MODE_STORAGE = 'storage';
const CONSOLE_MODE_SEQUENCER = 'sequencer';
const CONSOLE_MODE_ENZYMES = 'enzymes';
const CONSOLE_MODE_INJECTORS = 'injectors';

const STORAGE_MODE_CONSOLE = 'console';
const STORAGE_MODE_DISK = 'disk';
const STORAGE_MODE_ADVINJ = 'injector';

const STORAGE_CONS_SUBMODE_MUTATIONS = 'mutations';
const STORAGE_CONS_SUBMODE_CHROMOSOMES = 'chromosomes';
const STORAGE_DISK_SUBMODE_MUTATIONS = 'mutations';
const STORAGE_DISK_SUBMODE_ENZYMES = 'diskenzymes';

const CHROMOSOME_NEVER = 0;
const CHROMOSOME_NONE = 1;
const CHROMOSOME_USED = 2;

const MUT_NORMAL = 1;
const MUT_EXTRA = 2;
const MUT_OTHER = 3;

// __DEFINES/DNA.dm - Mutation "Quality"
const POSITIVE = 1;
const NEGATIVE = 2;
const MINOR_NEGATIVE = 4;
const MUT_COLORS = {
  1: 'good',
  2: 'bad',
  4: 'average',
};

const RADIATION_STRENGTH_MAX = 15;
const RADIATION_DURATION_MAX = 30;

/**
 * The following predicate tests if two mutations are functionally
 * the same on the basis of their metadata. Useful if your intent is
 * to prevent "true" duplicates - i.e. mutations with identical metadata.
 */
const isSameMutation = (a, b) => {
  return a.Alias === b.Alias && a.AppliedChromo === b.AppliedChromo;
};

export const DnaConsole = (props, context) => {
  const { data, act } = useBackend(context);
  const { isPulsingRads, radPulseSeconds } = data;
  const { consoleMode } = data.view;
  return (
    <Window title="Консоль ДНК" width={539} height={710}>
      {!!isPulsingRads && (
        <Dimmer fontSize="14px" textAlign="center">
          <Icon mr={1} name="spinner" spin />
          Импульс радиации в процессе...
          <Box mt={1} />
          {radPulseSeconds}с
        </Dimmer>
      )}
      <Window.Content scrollable>
        <DnaScanner />
        <DnaConsoleCommands />
        {consoleMode === CONSOLE_MODE_STORAGE && <DnaConsoleStorage />}
        {consoleMode === CONSOLE_MODE_SEQUENCER && <DnaConsoleSequencer />}
        {consoleMode === CONSOLE_MODE_ENZYMES && <DnaConsoleEnzymes />}
      </Window.Content>
    </Window>
  );
};

const DnaScanner = (props, context) => {
  return (
    <Section title="Сканер ДНК" buttons={<DnaScannerButtons />}>
      <DnaScannerContent />
    </Section>
  );
};

const DnaScannerButtons = (props, context) => {
  const { data, act } = useBackend(context);
  const {
    hasDelayedAction,
    isPulsingRads,
    isScannerConnected,
    isScrambleReady,
    isViableSubject,
    scannerLocked,
    scannerOpen,
    scrambleSeconds,
  } = data;
  if (!isScannerConnected) {
    return (
      <Button
        content="Подключить сканер"
        onClick={() => act('connect_scanner')}
      />
    );
  }
  return (
    <>
      {!!hasDelayedAction && (
        <Button
          content="Отменить отложенное действие"
          onClick={() => act('cancel_delay')}
        />
      )}
      {!!isViableSubject && (
        <Button
          disabled={!isScrambleReady || isPulsingRads}
          onClick={() => act('scramble_dna')}>
          Перемешать ДНК
          {!isScrambleReady && ` (${scrambleSeconds}с)`}
        </Button>
      )}
      <Box inline mr={1} />
      <Button
        icon={scannerLocked ? 'lock' : 'lock-open'}
        color={scannerLocked && 'bad'}
        disabled={scannerOpen}
        content={scannerLocked ? 'Заблокировано' : 'Разблокировано'}
        onClick={() => act('toggle_lock')}
      />
      <Button
        disabled={scannerLocked}
        content={scannerOpen ? 'Закрыть' : 'Открыть'}
        onClick={() => act('toggle_door')}
      />
    </>
  );
};

/**
 * Displays subject status based on the value of the status prop.
 */
const SubjectStatus = (props, context) => {
  const { status } = props;
  if (status === SUBJECT_CONCIOUS) {
    return (
      <Box inline color="good">
        В сознании
      </Box>
    );
  }
  if (status === SUBJECT_UNCONSCIOUS) {
    return (
      <Box inline color="average">
        Без сознания
      </Box>
    );
  }
  if (status === SUBJECT_SOFT_CRIT) {
    return (
      <Box inline color="average">
        Критический
      </Box>
    );
  }
  if (status === SUBJECT_DEAD) {
    return (
      <Box inline color="bad">
        Мёртв
      </Box>
    );
  }
  if (status === SUBJECT_TRANSFORMING) {
    return (
      <Box inline color="bad">
        Трансформируется
      </Box>
    );
  }
  return <Box inline>Неизвестный</Box>;
};

const DnaScannerContent = (props, context) => {
  const { data, act } = useBackend(context);
  const {
    subjectName,
    isScannerConnected,
    isViableSubject,
    subjectHealth,
    subjectRads,
    subjectStatus,
  } = data;
  if (!isScannerConnected) {
    return <Box color="bad">Сканер не подключен.</Box>;
  }
  if (!isViableSubject) {
    return <Box color="average">Не обнаружено подходящего пациента.</Box>;
  }
  return (
    <LabeledList>
      <LabeledList.Item label="Состояния">
        {subjectName}
        <Icon mx={1} color="label" name="long-arrow-alt-right" />
        <SubjectStatus status={subjectStatus} />
      </LabeledList.Item>
      <LabeledList.Item label="Здоровье">
        <ProgressBar
          value={subjectHealth}
          minValue={0}
          maxValue={100}
          ranges={{
            olive: [101, Infinity],
            good: [70, 101],
            average: [30, 70],
            bad: [-Infinity, 30],
          }}>
          {subjectHealth}%
        </ProgressBar>
      </LabeledList.Item>
      <LabeledList.Item label="Радиация">
        <ProgressBar
          value={subjectRads}
          minValue={0}
          maxValue={100}
          ranges={{
            bad: [71, Infinity],
            average: [30, 71],
            good: [0, 30],
            olive: [-Infinity, 0],
          }}>
          {subjectRads}%
        </ProgressBar>
      </LabeledList.Item>
    </LabeledList>
  );
};

export const DnaConsoleCommands = (props, context) => {
  const { data, act } = useBackend(context);
  const { hasDisk, isInjectorReady, injectorSeconds } = data;
  const { consoleMode } = data.view;
  return (
    <Section
      title="Консоль ДНК"
      buttons={
        !isInjectorReady && (
          <Box lineHeight="20px" color="label">
            Инъектор на перезарядке ({injectorSeconds}с)
          </Box>
        )
      }>
      <LabeledList>
        <LabeledList.Item label="Режим">
          <Button
            content="Хранилище"
            selected={consoleMode === CONSOLE_MODE_STORAGE}
            onClick={() =>
              act('set_view', {
                consoleMode: CONSOLE_MODE_STORAGE,
              })
            }
          />
          <Button
            content="Секвенсер"
            disabled={!data.isViableSubject}
            selected={consoleMode === CONSOLE_MODE_SEQUENCER}
            onClick={() =>
              act('set_view', {
                consoleMode: CONSOLE_MODE_SEQUENCER,
              })
            }
          />
          <Button
            content="Энзимы"
            selected={consoleMode === CONSOLE_MODE_ENZYMES}
            onClick={() =>
              act('set_view', {
                consoleMode: CONSOLE_MODE_ENZYMES,
              })
            }
          />
        </LabeledList.Item>
        {!!hasDisk && (
          <LabeledList.Item label="Диск">
            <Button
              icon="eject"
              content="Изъять"
              onClick={() => {
                act('eject_disk');
                act('set_view', {
                  storageMode: STORAGE_MODE_CONSOLE,
                });
              }}
            />
          </LabeledList.Item>
        )}
      </LabeledList>
    </Section>
  );
};

const StorageButtons = (props, context) => {
  const { data, act } = useBackend(context);
  const { hasDisk } = data;
  const { storageMode, storageConsSubMode, storageDiskSubMode } = data.view;
  return (
    <>
      {storageMode === STORAGE_MODE_CONSOLE && (
        <>
          <Button
            selected={storageConsSubMode === STORAGE_CONS_SUBMODE_MUTATIONS}
            content="Мутации"
            onClick={() =>
              act('set_view', {
                storageConsSubMode: STORAGE_CONS_SUBMODE_MUTATIONS,
              })
            }
          />
          <Button
            selected={storageConsSubMode === STORAGE_CONS_SUBMODE_CHROMOSOMES}
            content="Хромосомы"
            onClick={() =>
              act('set_view', {
                storageConsSubMode: STORAGE_CONS_SUBMODE_CHROMOSOMES,
              })
            }
          />
        </>
      )}
      {storageMode === STORAGE_MODE_DISK && (
        <>
          <Button
            selected={storageDiskSubMode === STORAGE_CONS_SUBMODE_MUTATIONS}
            content="Мутации"
            onClick={() =>
              act('set_view', {
                storageDiskSubMode: STORAGE_CONS_SUBMODE_MUTATIONS,
              })
            }
          />
          <Button
            selected={storageDiskSubMode === STORAGE_DISK_SUBMODE_ENZYMES}
            content="Энзимы"
            onClick={() =>
              act('set_view', {
                storageDiskSubMode: STORAGE_DISK_SUBMODE_ENZYMES,
              })
            }
          />
        </>
      )}
      <Box inline mr={1} />
      <Button
        content="Консоль"
        selected={storageMode === STORAGE_MODE_CONSOLE}
        onClick={() =>
          act('set_view', {
            storageMode: STORAGE_MODE_CONSOLE,
            storageConsSubMode:
              STORAGE_CONS_SUBMODE_MUTATIONS ?? storageConsSubMode,
          })
        }
      />
      <Button
        content="Диск"
        disabled={!hasDisk}
        selected={storageMode === STORAGE_MODE_DISK}
        onClick={() =>
          act('set_view', {
            storageMode: STORAGE_MODE_DISK,
            storageDiskSubMode:
              STORAGE_DISK_SUBMODE_MUTATIONS ?? storageDiskSubMode,
          })
        }
      />
      <Button
        content="Прод. Инъектор"
        selected={storageMode === STORAGE_MODE_ADVINJ}
        onClick={() =>
          act('set_view', {
            storageMode: STORAGE_MODE_ADVINJ,
          })
        }
      />
    </>
  );
};

const DnaConsoleStorage = (props, context) => {
  const { data, act } = useBackend(context);
  const { storageMode, storageConsSubMode, storageDiskSubMode } = data.view;
  const { diskMakeupBuffer, diskHasMakeup } = data;
  const mutations = data.storage[storageMode];
  return (
    <Section title="Хранилище" buttons={<StorageButtons />}>
      {storageMode === STORAGE_MODE_CONSOLE &&
        storageConsSubMode === STORAGE_CONS_SUBMODE_MUTATIONS && (
          <StorageMutations mutations={mutations} />
        )}
      {storageMode === STORAGE_MODE_CONSOLE &&
        storageConsSubMode === STORAGE_CONS_SUBMODE_CHROMOSOMES && (
          <StorageChromosomes />
        )}
      {storageMode === STORAGE_MODE_DISK &&
        storageDiskSubMode === STORAGE_DISK_SUBMODE_MUTATIONS && (
          <StorageMutations mutations={mutations} />
        )}
      {storageMode === STORAGE_MODE_DISK &&
        storageDiskSubMode === STORAGE_DISK_SUBMODE_ENZYMES && (
          <>
            <GeneticMakeupInfo makeup={diskMakeupBuffer} />
            <Button
              icon="times"
              color="red"
              disabled={!diskHasMakeup}
              content={'Удалить'}
              onClick={() => act('del_makeup_disk')}
            />
          </>
        )}
      {storageMode === STORAGE_MODE_ADVINJ && <DnaConsoleAdvancedInjectors />}
    </Section>
  );
};

const StorageMutations = (props, context) => {
  const { customMode = '' } = props;
  const { data, act } = useBackend(context);
  const mutations = props.mutations || [];
  const mode = data.view.storageMode + customMode;

  let mutationRef = data.view[`storage${mode}MutationRef`];
  let mutation = mutations.find(
    (mutation) => mutation.ByondRef === mutationRef
  );

  // If no mutation is selected but there are stored mutations, pick the first
  // mutation and set that as the currently showed one.
  if (!mutation && mutations.length > 0) {
    mutation = mutations[0];
    mutationRef = mutation.ByondRef;
  }

  return (
    <Flex>
      <Flex.Item width="140px">
        <Section
          title={`${capitalize(data.view.storageMode)} Хранилище`}
          level={2}>
          {mutations.map((mutation) => (
            <Button
              key={mutation.ByondRef}
              fluid
              ellipsis
              color="transparent"
              selected={mutation.ByondRef === mutationRef}
              content={mutation.Name}
              onClick={() =>
                act('set_view', {
                  [`storage${mode}MutationRef`]: mutation.ByondRef,
                })
              }
            />
          ))}
        </Section>
      </Flex.Item>
      <Flex.Item>
        <Divider vertical />
      </Flex.Item>
      <Flex.Item grow={1} basis={0}>
        <Section title="Мутация" level={2}>
          <MutationInfo mutation={mutation} />
        </Section>
      </Flex.Item>
    </Flex>
  );
};

const StorageChromosomes = (props, context) => {
  const { data, act } = useBackend(context);
  const chromos = data.chromoStorage ?? [];
  const uniqueChromos = uniqBy((chromo) => chromo.Name)(chromos);
  const chromoName = data.view.storageChromoName;
  const chromo = chromos.find((chromo) => chromo.Name === chromoName);
  return (
    <Flex>
      <Flex.Item width="140px">
        <Section title="Хранилище консоли" level={2}>
          {uniqueChromos.map((chromo) => (
            <Button
              key={chromo.Index}
              fluid
              ellipsis
              color="transparent"
              selected={chromo.Name === chromoName}
              content={chromo.Name}
              onClick={() =>
                act('set_view', {
                  storageChromoName: chromo.Name,
                })
              }
            />
          ))}
        </Section>
      </Flex.Item>
      <Flex.Item>
        <Divider vertical />
      </Flex.Item>
      <Flex.Item grow={1} basis={0}>
        <Section title="Хромосомы" level={2}>
          {(!chromo && <Box color="label">Нечего показывать.</Box>) || (
            <>
              <LabeledList>
                <LabeledList.Item label="Имя">{chromo.Name}</LabeledList.Item>
                <LabeledList.Item label="Описание">
                  {chromo.Description}
                </LabeledList.Item>
                <LabeledList.Item label="Количество">
                  {chromos.filter((x) => x.Name === chromo.Name).length}
                </LabeledList.Item>
              </LabeledList>
              <Button
                mt={2}
                icon="eject"
                content={'Изъять'}
                onClick={() =>
                  act('eject_chromo', {
                    chromo: chromo.Name,
                  })
                }
              />
            </>
          )}
        </Section>
      </Flex.Item>
    </Flex>
  );
};

const MutationInfo = (props, context) => {
  const { mutation } = props;
  const { data, act } = useBackend(context);
  const {
    diskCapacity,
    diskReadOnly,
    hasDisk,
    isInjectorReady,
    isCrisprReady,
    crisprCharges,
  } = data;
  const diskMutations = data.storage.disk ?? [];
  const mutationStorage = data.storage.console ?? [];
  const advInjectors = data.storage.injector ?? [];
  if (!mutation) {
    return <Box color="label">Нечего показывать.</Box>;
  }
  if (mutation.Source === 'occupant' && !mutation.Discovered) {
    return (
      <LabeledList>
        <LabeledList.Item label="Имя">{mutation.Alias}</LabeledList.Item>
      </LabeledList>
    );
  }
  const savedToConsole = mutationStorage.find((x) =>
    isSameMutation(x, mutation)
  );
  const savedToDisk = diskMutations.find((x) => isSameMutation(x, mutation));
  const combinedMutations = flow([
    uniqBy((mutation) => mutation.Name),
    filter((x) => x.Name !== mutation.Name),
  ])([...diskMutations, ...mutationStorage]);
  return (
    <>
      <LabeledList>
        <LabeledList.Item label="Имя">
          <Box inline color={MUT_COLORS[mutation.Quality]}>
            {mutation.Name}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Описание">
          {mutation.Description}
        </LabeledList.Item>
        <LabeledList.Item label="Нестабильность">
          {mutation.Instability}
        </LabeledList.Item>
      </LabeledList>
      <Divider />
      <Box>
        {mutation.Source === 'disk' && (
          <MutationCombiner
            disabled={!hasDisk || diskCapacity <= 0 || diskReadOnly}
            mutations={combinedMutations}
            source={mutation}
          />
        )}
        {mutation.Source === 'console' && (
          <MutationCombiner mutations={combinedMutations} source={mutation} />
        )}
        {['occupant', 'disk', 'console'].includes(mutation.Source) && (
          <>
            <Dropdown
              width="240px"
              options={advInjectors.map((injector) => injector.name)}
              disabled={advInjectors.length === 0 || !mutation.Active}
              selected="Добавить к продвинутому инъектору"
              onSelected={(value) =>
                act('add_advinj_mut', {
                  mutref: mutation.ByondRef,
                  advinj: value,
                  source: mutation.Source,
                })
              }
            />
            <Button
              icon="syringe"
              disabled={!isInjectorReady || !mutation.Active}
              content="Создать активатор"
              onClick={() =>
                act('print_injector', {
                  mutref: mutation.ByondRef,
                  is_activator: 1,
                  source: mutation.Source,
                })
              }
            />
            <Button
              icon="syringe"
              disabled={!isInjectorReady || !mutation.Active}
              content="Создать мутатор"
              onClick={() =>
                act('print_injector', {
                  mutref: mutation.ByondRef,
                  is_activator: 0,
                  source: mutation.Source,
                })
              }
            />
            <Button
              icon="syringe"
              disabled={!mutation.Active || !isCrisprReady}
              content={`CRISPR [${crisprCharges}]`}
              onClick={() =>
                act('crispr', {
                  mutref: mutation.ByondRef,
                  source: mutation.Source,
                })
              }
            />
          </>
        )}
      </Box>
      {['disk', 'occupant'].includes(mutation.Source) && (
        <Button
          icon="save"
          disabled={savedToConsole || !mutation.Active}
          content="Сохранить в консоль"
          onClick={() =>
            act('save_console', {
              mutref: mutation.ByondRef,
              source: mutation.Source,
            })
          }
        />
      )}
      {['console', 'occupant'].includes(mutation.Source) && (
        <Button
          icon="save"
          disabled={
            savedToDisk ||
            !hasDisk ||
            diskCapacity <= 0 ||
            diskReadOnly ||
            !mutation.Active
          }
          content="Сохранить на диск"
          onClick={() =>
            act('save_disk', {
              mutref: mutation.ByondRef,
              source: mutation.Source,
            })
          }
        />
      )}
      {['console', 'disk', 'injector'].includes(mutation.Source) && (
        <Button
          icon="times"
          color="red"
          content={`Удалить из ${mutation.Source}`}
          onClick={() =>
            act(`delete_${mutation.Source}_mut`, {
              mutref: mutation.ByondRef,
            })
          }
        />
      )}
      {(mutation.Class === MUT_EXTRA ||
        (!!mutation.Scrambled && mutation.Source === 'occupant')) && (
        <Button
          content="Обнулить"
          onClick={() =>
            act('nullify', {
              mutref: mutation.ByondRef,
            })
          }
        />
      )}
      <Divider />
      <ChromosomeInfo
        disabled={mutation.Source !== 'occupant'}
        mutation={mutation}
      />
    </>
  );
};

const ChromosomeInfo = (props, context) => {
  const { mutation, disabled } = props;
  const { data, act } = useBackend(context);
  if (mutation.CanChromo === CHROMOSOME_NEVER) {
    return <Box color="label">Нет подходящих хромосом.</Box>;
  }
  if (mutation.CanChromo === CHROMOSOME_NONE) {
    if (disabled) {
      return <Box color="label">Никаких хромосом не применено.</Box>;
    }
    return (
      <>
        <Dropdown
          width="240px"
          options={mutation.ValidStoredChromos}
          disabled={mutation.ValidStoredChromos.length === 0}
          selected={
            mutation.ValidStoredChromos.length === 0
              ? 'Нет подходящих хромосом'
              : 'Выберите хромосому'
          }
          onSelected={(e) =>
            act('apply_chromo', {
              chromo: e,
              mutref: mutation.ByondRef,
            })
          }
        />
        <Box color="label" mt={1}>
          Совместимо с: {mutation.ValidChromos}
        </Box>
      </>
    );
  }
  if (mutation.CanChromo === CHROMOSOME_USED) {
    return (
      <Box color="label">Применимая хромосома: {mutation.AppliedChromo}</Box>
    );
  }
  return null;
};

const DnaConsoleSequencer = (props, context) => {
  const { data, act } = useBackend(context);
  const mutations = data.storage?.occupant ?? [];
  const { isJokerReady, isMonkey, jokerSeconds, subjectStatus } = data;
  const { sequencerMutation, jokerActive } = data.view;
  const mutation = mutations.find(
    (mutation) => mutation.Alias === sequencerMutation
  );
  return (
    <>
      <Stack mb={1}>
        <Stack.Item width={(mutations.length <= 8 && '154px') || '174px'}>
          <Section
            title="Мутации"
            height="214px"
            overflowY={mutations.length > 8 && 'scroll'}>
            {mutations.map((mutation) => (
              <GenomeImage
                key={mutation.Alias}
                url={resolveAsset(mutation.Image)}
                selected={mutation.Alias === sequencerMutation}
                onClick={() => {
                  act('set_view', {
                    sequencerMutation: mutation.Alias,
                  });
                  act('check_discovery', {
                    alias: mutation.Alias,
                  });
                }}
              />
            ))}
          </Section>
        </Stack.Item>
        <Stack.Item grow={1} basis={0}>
          <Section title="Последовательность" minHeight="100%">
            <MutationInfo mutation={mutation} />
          </Section>
        </Stack.Item>
      </Stack>
      {(subjectStatus === SUBJECT_DEAD && (
        <Section color="bad">
          Генетическая последовательность повреждена. Пациент МЁРТВ.
        </Section>
      )) ||
        (isMonkey && mutation?.Name !== 'Манкификация' && (
          <Section color="bad">
            Генетическая последовательность повреждена. Пациент МАРТЫШКА.
          </Section>
        )) ||
        (subjectStatus === SUBJECT_TRANSFORMING && (
          <Section color="bad">
            Генетическая последовательность повреждена. Пациент
            ТРАНСФОРМИРУЕТСЯ.
          </Section>
        )) || (
          <Section
            title="Последовательность генома™"
            buttons={
              (!isJokerReady && (
                <Box lineHeight="20px" color="label">
                  Джокер на перезарядке ({jokerSeconds}с)
                </Box>
              )) ||
              (jokerActive && (
                <>
                  <Box mr={1} inline color="label">
                    Нажми на геном для раскрытия.
                  </Box>
                  <Button
                    content="Отмена Джокера"
                    onClick={() =>
                      act('set_view', {
                        jokerActive: '',
                      })
                    }
                  />
                </>
              )) || (
                <Button
                  icon="crown"
                  color="purple"
                  content="Использовать Джокер"
                  onClick={() =>
                    act('set_view', {
                      jokerActive: '1',
                    })
                  }
                />
              )
            }>
            <GenomeSequencer mutation={mutation} />
          </Section>
        )}
    </>
  );
};

const GenomeImage = (props, context) => {
  const { url, selected, onClick } = props;
  let outline;
  if (selected) {
    outline = '2px solid #22aa00';
  }
  return (
    <Box
      as="img"
      src={url}
      style={{
        width: '64px',
        margin: '2px',
        'margin-left': '4px',
        outline,
      }}
      onClick={onClick}
    />
  );
};

const GeneCycler = (props, context) => {
  const { gene, onChange, disabled, ...rest } = props;
  const length = GENES.length;
  const index = GENES.indexOf(gene);
  const color = (disabled && GENE_COLORS['X']) || GENE_COLORS[gene];
  return (
    <Button
      {...rest}
      color={color}
      onClick={(e) => {
        e.preventDefault();
        if (!onChange) {
          return;
        }
        if (index === -1) {
          onChange(e, GENES[0]);
          return;
        }
        const nextGene = GENES[(index + 1) % length];
        onChange(e, nextGene);
      }}
      oncontextmenu={(e) => {
        e.preventDefault();
        if (!onChange) {
          return;
        }
        if (index === -1) {
          onChange(e, GENES[length - 1]);
          return;
        }
        const prevGene = GENES[(index - 1 + length) % length];
        onChange(e, prevGene);
      }}>
      {gene}
    </Button>
  );
};

const GenomeSequencer = (props, context) => {
  const { mutation } = props;
  const { data, act } = useBackend(context);
  const { jokerActive } = data.view;
  if (!mutation) {
    return <Box color="average">Геном не выбран.</Box>;
  }
  if (mutation.Scrambled) {
    return (
      <Box color="average">
        Последовательность невозможно прочитать из-за мутации.
      </Box>
    );
  }
  // Create gene cycler buttons
  const sequence = mutation.Sequence;
  const defaultSeq = mutation.DefaultSeq;
  const buttons = [];
  for (let i = 0; i < sequence.length; i++) {
    const gene = sequence.charAt(i);
    const button = (
      <GeneCycler
        width="22px"
        height="22px"
        textAlign="center"
        disabled={!!mutation.Scrambled || mutation.Class !== MUT_NORMAL}
        className={
          defaultSeq?.charAt(i) === 'X' && !mutation.Active
            ? classes(['outline-solid', 'outline-color-orange'])
            : false
        }
        gene={gene}
        onChange={(e, nextGene) => {
          if (e.ctrlKey) {
            act('pulse_gene', {
              pos: i + 1,
              gene: 'X',
              alias: mutation.Alias,
            });
            return;
          }
          if (jokerActive) {
            act('pulse_gene', {
              pos: i + 1,
              gene: 'J',
              alias: mutation.Alias,
            });
            act('set_view', {
              jokerActive: '',
            });
            return;
          }
          act('pulse_gene', {
            pos: i + 1,
            gene: nextGene,
            alias: mutation.Alias,
          });
        }}
      />
    );
    buttons.push(button);
  }
  // Render genome in two rows
  const pairs = [];
  for (let i = 0; i < buttons.length; i += 2) {
    const pair = (
      <Box key={i} inline m={0.5}>
        {buttons[i]}
        <Box
          mt="-2px"
          ml="10px"
          width="2px"
          height="8px"
          backgroundColor="label"
        />
        {buttons[i + 1]}
      </Box>
    );

    if (i % 8 === 0 && i !== 0) {
      pairs.push(
        <Box
          key={`${i}_divider`}
          inline
          position="relative"
          top="-17px"
          left="-1px"
          width="8px"
          height="2px"
          backgroundColor="label"
        />
      );
    }

    pairs.push(pair);
  }
  return (
    <>
      <Box m={-0.5}>{pairs}</Box>
      <Box color="label" mt={1}>
        <b>Заметка:</b> Ctrl+Клик на геноме для X. Правый клик для реверса.
      </Box>
    </>
  );
};

const DnaConsoleEnzymes = (props, context) => {
  const { data, act } = useBackend(context);
  const { isScannerConnected } = data;
  if (!isScannerConnected) {
    return <Section color="bad">Сканер ДНК не подключен.</Section>;
  }
  return (
    <>
      <Stack mb={1}>
        <Stack.Item width="155px">
          <RadiationEmitterSettings />
        </Stack.Item>
        <Stack.Item width="140px">
          <RadiationEmitterProbs />
        </Stack.Item>
        <Stack.Item grow={1} basis={0}>
          <RadiationEmitterPulseBoard />
        </Stack.Item>
      </Stack>
      <GeneticMakeupBuffers />
    </>
  );
};

const RadiationEmitterSettings = (props, context) => {
  const { data, act } = useBackend(context);
  const { radStrength, radDuration } = data;
  return (
    <Section title="Излучатель радиации" minHeight="100%">
      <LabeledList>
        <LabeledList.Item label="Уровень выхода">
          <NumberInput
            animated
            width="32px"
            stepPixelSize={10}
            value={radStrength}
            minValue={1}
            maxValue={RADIATION_STRENGTH_MAX}
            onDrag={(e, value) =>
              act('set_pulse_strength', {
                val: value,
              })
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Импульс">
          <NumberInput
            animated
            width="32px"
            stepPixelSize={10}
            value={radDuration}
            minValue={1}
            maxValue={RADIATION_DURATION_MAX}
            onDrag={(e, value) =>
              act('set_pulse_duration', {
                val: value,
              })
            }
          />
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const RadiationEmitterProbs = (props, context) => {
  const { data } = useBackend(context);
  const { stdDevAcc, stdDevStr } = data;
  return (
    <Section title="Вероятности" minHeight="100%">
      <LabeledList>
        <LabeledList.Item label="Точность" textAlign="right">
          {stdDevAcc}
        </LabeledList.Item>
        <LabeledList.Item label={`P(±${stdDevStr})`} textAlign="right">
          68 %
        </LabeledList.Item>
        <LabeledList.Item label={`P(±${stdDevStr * 2})`} textAlign="right">
          95 %
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const RadiationEmitterPulseBoard = (props, context) => {
  const { data, act } = useBackend(context);
  const { subjectUNI = [] } = data;
  // Build blocks of buttons of unique enzymes
  const blocks = [];
  let buffer = [];
  for (let i = 0; i < subjectUNI.length; i++) {
    const char = subjectUNI.charAt(i);
    // Push a button into the buffer
    const button = (
      <Button
        fluid
        key={i}
        textAlign="center"
        content={char}
        onClick={() =>
          act('makeup_pulse', {
            index: i + 1,
          })
        }
      />
    );
    buffer.push(button);
    // Create a block from the current buffer
    if (buffer.length >= 3) {
      const block = (
        <Box inline width="22px" mx="1px">
          {buffer}
        </Box>
      );
      blocks.push(block);
      // Clear the buffer
      buffer = [];
    }
  }
  return (
    <Section title="Уникальные энзимы" minHeight="100%" position="relative">
      <Box mx="-1px">{blocks}</Box>
    </Section>
  );
};

const GeneticMakeupBuffers = (props, context) => {
  const { data, act } = useBackend(context);
  const {
    diskHasMakeup,
    hasDisk,
    isViableSubject,
    makeupCapacity = 3,
    makeupStorage,
  } = data;
  const elements = [];
  for (let i = 1; i <= makeupCapacity; i++) {
    const makeup = makeupStorage[i];
    const element = (
      <Collapsible
        title={makeup ? makeup.label || makeup.name : `Слот ${i}`}
        buttons={
          <>
            {!!(hasDisk && diskHasMakeup) && (
              <Button
                mr={1}
                disabled={!hasDisk || !diskHasMakeup}
                content="Импорт с диска"
                onClick={() =>
                  act('load_makeup_disk', {
                    index: i,
                  })
                }
              />
            )}
            <Button
              disabled={!isViableSubject}
              content="Сохранить"
              onClick={() =>
                act('save_makeup_console', {
                  index: i,
                })
              }
            />
            <Button
              ml={1}
              icon="times"
              color="red"
              disabled={!makeup}
              onClick={() =>
                act('del_makeup_console', {
                  index: i,
                })
              }
            />
          </>
        }>
        <GeneticMakeupBufferInfo index={i} makeup={makeup} />
      </Collapsible>
    );
    elements.push(element);
  }
  return <Section title="Буфферы генетического макияжа">{elements}</Section>;
};

const GeneticMakeupInfo = (props, context) => {
  const { makeup } = props;

  return (
    <Section title="Энзимы">
      <LabeledList>
        <LabeledList.Item label="Имя">{makeup.name || 'Нет'}</LabeledList.Item>
        <LabeledList.Item label="Тип крови">
          {makeup.blood_type || 'Нет'}
        </LabeledList.Item>
        <LabeledList.Item label="Уникальный энзим">
          {makeup.UE || 'Нет'}
        </LabeledList.Item>
        <LabeledList.Item label="Уникальный идентификатор">
          {makeup.UI || 'Нет'}
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const GeneticMakeupBufferInfo = (props, context) => {
  const { index, makeup } = props;
  const { act, data } = useBackend(context);
  const { isViableSubject, hasDisk, diskReadOnly, isInjectorReady } = data;
  // Type of the action for applying makeup
  const ACTION_MAKEUP_APPLY = isViableSubject ? 'makeup_apply' : 'makeup_delay';
  if (!makeup) {
    return <Box color="average">Нет сохранённых данных.</Box>;
  }
  return (
    <>
      <GeneticMakeupInfo makeup={makeup} />
      <Divider />
      <Box bold color="label" mb={1}>
        Действия макияжа
      </Box>
      <LabeledList>
        <LabeledList.Item label="Энзимы">
          <Button
            icon="syringe"
            disabled={!isInjectorReady}
            content="Печать"
            onClick={() =>
              act('makeup_injector', {
                index,
                type: 'ue',
              })
            }
          />
          <Button
            icon="exchange-alt"
            onClick={() =>
              act(ACTION_MAKEUP_APPLY, {
                index,
                type: 'ue',
              })
            }>
            Трансфер
            {!isViableSubject && ' (Отложенный)'}
          </Button>
        </LabeledList.Item>
        <LabeledList.Item label="Личность">
          <Button
            icon="syringe"
            disabled={!isInjectorReady}
            content="Печать"
            onClick={() =>
              act('makeup_injector', {
                index,
                type: 'ui',
              })
            }
          />
          <Button
            icon="exchange-alt"
            onClick={() =>
              act(ACTION_MAKEUP_APPLY, {
                index,
                type: 'ui',
              })
            }>
            Трансфер
            {!isViableSubject && ' (Отложенный)'}
          </Button>
        </LabeledList.Item>
        <LabeledList.Item label="Полный макияж">
          <Button
            icon="syringe"
            disabled={!isInjectorReady}
            content="Печать"
            onClick={() =>
              act('makeup_injector', {
                index,
                type: 'mixed',
              })
            }
          />
          <Button
            icon="exchange-alt"
            onClick={() =>
              act(ACTION_MAKEUP_APPLY, {
                index,
                type: 'mixed',
              })
            }>
            Трансфер
            {!isViableSubject && ' (Отложенный)'}
          </Button>
        </LabeledList.Item>
        <LabeledList.Item>
          <Button
            icon="save"
            disabled={!hasDisk || diskReadOnly}
            content="Экспорт на диск"
            onClick={() =>
              act('save_makeup_disk', {
                index,
              })
            }
          />
        </LabeledList.Item>
      </LabeledList>
    </>
  );
};

const DnaConsoleAdvancedInjectors = (props, context) => {
  const { act, data } = useBackend(context);
  const { maxAdvInjectors, isInjectorReady } = data;
  const advInjectors = data.storage.injector ?? [];
  return (
    <Section title="Продвинутые инъекторы">
      {advInjectors.map((injector) => (
        <Collapsible
          key={injector.name}
          title={injector.name}
          buttons={
            <>
              <Button
                icon="syringe"
                disabled={!isInjectorReady}
                content="Печать"
                onClick={() =>
                  act('print_adv_inj', {
                    name: injector.name,
                  })
                }
              />
              <Button
                ml={1}
                color="red"
                icon="times"
                onClick={() =>
                  act('del_adv_inj', {
                    name: injector.name,
                  })
                }
              />
            </>
          }>
          <StorageMutations
            mutations={injector.mutations}
            customMode={`advinj${advInjectors.findIndex(
              (e) => injector.name === e.name
            )}`}
          />
        </Collapsible>
      ))}
      <Box mt={2}>
        <Button.Input
          minWidth="200px"
          content="Создать новый инъектор"
          disabled={advInjectors.length >= maxAdvInjectors}
          onCommit={(e, value) =>
            act('new_adv_inj', {
              name: value,
            })
          }
        />
      </Box>
    </Section>
  );
};

const MutationCombiner = (props, context) => {
  const { mutations = [], source } = props;
  const { act, data } = useBackend(context);

  const brefFromName = (name) => {
    return mutations.find((mutation) => mutation.Name === name)?.ByondRef;
  };

  return (
    <Dropdown
      key={source.ByondRef}
      width="240px"
      options={mutations.map((mutation) => mutation.Name)}
      disabled={mutations.length === 0}
      selected="Комбинировать мутации"
      onSelected={(value) =>
        act(`combine_${source.Source}`, {
          firstref: brefFromName(value),
          secondref: source.ByondRef,
        })
      }
    />
  );
};
